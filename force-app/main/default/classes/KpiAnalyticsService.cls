/**
 * Builds and runs the dynamic aggregate SOQL behind a KPI. Safety model
 * mirrors the Opportunity Map project: object/field names come from
 * admin-configured Custom Metadata and are validated against
 * Schema.describe (KpiFieldMetadata) before ever touching a query string;
 * the only true end-user input, the period in days, goes through a bind
 * variable. Runs WITH USER_MODE so CRUD/FLS is enforced end to end.
 */
public with sharing class KpiAnalyticsService {
  public static final Integer DEFAULT_PERIOD_DAYS = 30;
  public static final Integer MAX_GROUPS = 25;

  public class KpiDataPoint {
    @AuraEnabled
    public String groupKey;
    @AuraEnabled
    public String groupLabel;
    @AuraEnabled
    public Decimal value;
  }

  public class KpiResult {
    @AuraEnabled
    public String developerName;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String chartType;
    @AuraEnabled
    public String iconName;
    @AuraEnabled
    public String aggregateFunction;
    @AuraEnabled
    public Decimal total;
    @AuraEnabled
    public List<KpiDataPoint> dataPoints;
  }

  public static KpiResult getKpiData(String developerName, Integer periodDays) {
    KPI_Definition__mdt def = KpiDefinitionSelector.getByDeveloperName(
      developerName
    );
    if (def == null) {
      throw new KpiFieldMetadata.InvalidKpiConfigException(
        'Unknown or inactive KPI: ' + developerName
      );
    }
    Integer effectivePeriod = (periodDays == null ||
      periodDays <= 0)
      ? DEFAULT_PERIOD_DAYS
      : periodDays;

    KpiFieldMetadata.ResolvedFields fields = KpiFieldMetadata.resolve(def);
    String groupByField = def.Group_By_Field_API_Name__c;
    String dateField = def.Date_Field_API_Name__c;
    String selectExpr = def.Aggregate_Function__c == 'COUNT'
      ? 'COUNT(Id)'
      : def.Aggregate_Function__c + '(' + def.Aggregate_Field_API_Name__c + ')';

    Date startDate = Date.today().addDays(-effectivePeriod);
    String soql =
      'SELECT ' +
      groupByField +
      ', ' +
      selectExpr +
      ' agg' +
      ' FROM ' +
      def.Object_API_Name__c +
      ' WHERE ' +
      dateField +
      ' >= :startDate AND ' +
      dateField +
      ' <= :endDate' +
      ' GROUP BY ' +
      groupByField +
      ' ORDER BY ' +
      selectExpr +
      ' DESC' +
      ' LIMIT ' +
      MAX_GROUPS;

    Map<String, Object> binds = new Map<String, Object>{
      'startDate' => startDate,
      'endDate' => Date.today()
    };
    List<AggregateResult> rows = Database.queryWithBinds(
      soql,
      binds,
      AccessLevel.USER_MODE
    );

    Map<String, String> labelsByKey = resolveGroupLabels(
      fields,
      rows,
      groupByField
    );

    KpiResult result = new KpiResult();
    result.developerName = def.DeveloperName;
    result.label = def.MasterLabel;
    result.chartType = def.Chart_Type__c;
    result.iconName = def.Icon_Name__c;
    result.aggregateFunction = def.Aggregate_Function__c;
    result.dataPoints = new List<KpiDataPoint>();
    Decimal total = 0;
    for (AggregateResult ar : rows) {
      Object rawKey = ar.get(groupByField);
      String key = rawKey == null ? '(vazio)' : String.valueOf(rawKey);
      Decimal value = (Decimal) ar.get('agg');
      if (value == null) {
        value = 0;
      }
      KpiDataPoint point = new KpiDataPoint();
      point.groupKey = key;
      point.groupLabel = labelsByKey.containsKey(key)
        ? labelsByKey.get(key)
        : key;
      point.value = value;
      result.dataPoints.add(point);
      total += value;
    }
    result.total = total;
    return result;
  }

  public class DrilldownResult {
    @AuraEnabled
    public List<SObject> records;
    @AuraEnabled
    public List<String> columns; // API names to render as datatable columns
  }

  /** Underlying records behind one chart slice, for the "see the records" drilldown. */
  public static DrilldownResult getDrilldownRecords(
    String developerName,
    String groupKey,
    Integer periodDays
  ) {
    KPI_Definition__mdt def = KpiDefinitionSelector.getByDeveloperName(
      developerName
    );
    if (def == null) {
      throw new KpiFieldMetadata.InvalidKpiConfigException(
        'Unknown or inactive KPI: ' + developerName
      );
    }
    Integer effectivePeriod = (periodDays == null ||
      periodDays <= 0)
      ? DEFAULT_PERIOD_DAYS
      : periodDays;
    KpiFieldMetadata.ResolvedFields fields = KpiFieldMetadata.resolve(def);

    List<String> columns = new List<String>{ 'Name' };
    if (def.Aggregate_Function__c != 'COUNT') {
      columns.add(def.Aggregate_Field_API_Name__c);
    }
    columns.add(def.Date_Field_API_Name__c);

    Date startDate = Date.today().addDays(-effectivePeriod);
    // Deliberately not a ternary: Apex unifies ternary branch types at
    // compile time, and since String->Id has an implicit conversion, it
    // would silently coerce the picklist branch to Id too and blow up at
    // runtime on any non-Id group value (e.g. "Prospecting").
    Object groupValue;
    if (fields.groupByField.getType() == Schema.DisplayType.REFERENCE) {
      groupValue = (Id) groupKey;
    } else {
      groupValue = groupKey;
    }

    String soql =
      'SELECT Id, ' +
      String.join(columns, ', ') +
      ' FROM ' +
      def.Object_API_Name__c +
      ' WHERE ' +
      def.Group_By_Field_API_Name__c +
      ' = :groupValue' +
      ' AND ' +
      def.Date_Field_API_Name__c +
      ' >= :startDate AND ' +
      def.Date_Field_API_Name__c +
      ' <= :endDate' +
      ' ORDER BY ' +
      def.Date_Field_API_Name__c +
      ' DESC' +
      ' LIMIT 50';

    Map<String, Object> binds = new Map<String, Object>{
      'groupValue' => groupValue,
      'startDate' => startDate,
      'endDate' => Date.today()
    };
    DrilldownResult result = new DrilldownResult();
    result.records = Database.queryWithBinds(
      soql,
      binds,
      AccessLevel.USER_MODE
    );
    result.columns = columns;
    return result;
  }

  /** Turns raw group-by values (Ids, picklist API names) into human-readable labels. */
  private static Map<String, String> resolveGroupLabels(
    KpiFieldMetadata.ResolvedFields fields,
    List<AggregateResult> rows,
    String groupByField
  ) {
    Map<String, String> labels = new Map<String, String>();
    if (fields.groupByField.getType() == Schema.DisplayType.REFERENCE) {
      Set<Id> ids = new Set<Id>();
      for (AggregateResult ar : rows) {
        Object rawKey = ar.get(groupByField);
        if (rawKey != null) {
          ids.add((Id) rawKey);
        }
      }
      List<Schema.SObjectType> refs = fields.groupByField.getReferenceTo();
      if (!ids.isEmpty() && !refs.isEmpty()) {
        String refObject = refs[0].getDescribe().getName();
        for (
          SObject rec : Database.query(
            'SELECT Id, Name FROM ' +
              refObject +
              ' WHERE Id IN :ids WITH USER_MODE'
          )
        ) {
          labels.put(
            String.valueOf(rec.get('Id')),
            String.valueOf(rec.get('Name'))
          );
        }
      }
    } else if (fields.groupByField.getType() == Schema.DisplayType.PICKLIST) {
      for (
        Schema.PicklistEntry entry : fields.groupByField.getPicklistValues()
      ) {
        labels.put(entry.getValue(), entry.getLabel());
      }
    }
    return labels;
  }
}

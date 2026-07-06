/**
 * Schema.describe-backed validation for everything a KPI_Definition__mdt row
 * points at. Nothing here trusts field names blindly: the object must be
 * queryable, the group-by field must be groupable, and the aggregate field
 * (when present) must be a summable numeric type. This is the same
 * describe-whitelist pattern used by the Opportunity Map project, applied to
 * an arbitrary admin-configured object instead of a single hardcoded one.
 */
public inherited sharing class KpiFieldMetadata {
  public class InvalidKpiConfigException extends Exception {
  }

  public class ResolvedFields {
    public Schema.DescribeSObjectResult objectDescribe;
    public Schema.DescribeFieldResult groupByField;
    public Schema.DescribeFieldResult aggregateField; // null when COUNT
    public Schema.DescribeFieldResult dateField;
  }

  public static ResolvedFields resolve(KPI_Definition__mdt def) {
    Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    Schema.SObjectType sObjType = globalDescribe.get(def.Object_API_Name__c);
    if (sObjType == null) {
      throw new InvalidKpiConfigException(
        'Unknown object: ' + def.Object_API_Name__c
      );
    }
    Schema.DescribeSObjectResult objectDescribe = sObjType.getDescribe();
    if (!objectDescribe.isAccessible() || !objectDescribe.isQueryable()) {
      throw new InvalidKpiConfigException(
        'Object not accessible: ' + def.Object_API_Name__c
      );
    }
    Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();

    ResolvedFields result = new ResolvedFields();
    result.objectDescribe = objectDescribe;
    result.groupByField = requireField(
      fieldMap,
      def.Group_By_Field_API_Name__c,
      objectDescribe
    );
    if (!result.groupByField.isGroupable()) {
      throw new InvalidKpiConfigException(
        'Field is not groupable: ' + def.Group_By_Field_API_Name__c
      );
    }
    result.dateField = requireField(
      fieldMap,
      def.Date_Field_API_Name__c,
      objectDescribe
    );
    Schema.DisplayType dateType = result.dateField.getType();
    if (
      dateType != Schema.DisplayType.DATE &&
      dateType != Schema.DisplayType.DATETIME
    ) {
      throw new InvalidKpiConfigException(
        'Date field is not a Date/DateTime: ' + def.Date_Field_API_Name__c
      );
    }

    if (def.Aggregate_Function__c != 'COUNT') {
      if (String.isBlank(def.Aggregate_Field_API_Name__c)) {
        throw new InvalidKpiConfigException(
          'Aggregate field is required for ' + def.Aggregate_Function__c
        );
      }
      result.aggregateField = requireField(
        fieldMap,
        def.Aggregate_Field_API_Name__c,
        objectDescribe
      );
      Schema.DisplayType aggType = result.aggregateField.getType();
      Set<Schema.DisplayType> summable = new Set<Schema.DisplayType>{
        Schema.DisplayType.CURRENCY,
        Schema.DisplayType.DOUBLE,
        Schema.DisplayType.INTEGER,
        Schema.DisplayType.PERCENT
      };
      if (!summable.contains(aggType)) {
        throw new InvalidKpiConfigException(
          'Aggregate field is not numeric: ' + def.Aggregate_Field_API_Name__c
        );
      }
    }
    return result;
  }

  private static Schema.DescribeFieldResult requireField(
    Map<String, Schema.SObjectField> fieldMap,
    String fieldName,
    Schema.DescribeSObjectResult objectDescribe
  ) {
    if (
      String.isBlank(fieldName) ||
      !fieldMap.containsKey(fieldName.toLowerCase())
    ) {
      throw new InvalidKpiConfigException(
        'Unknown field ' + fieldName + ' on ' + objectDescribe.getName()
      );
    }
    Schema.DescribeFieldResult fieldDescribe = fieldMap.get(
        fieldName.toLowerCase()
      )
      .getDescribe();
    if (!fieldDescribe.isAccessible()) {
      throw new InvalidKpiConfigException('Field not accessible: ' + fieldName);
    }
    return fieldDescribe;
  }
}

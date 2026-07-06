@IsTest
public class KpiTestDataFactory {
  public static KPI_Definition__mdt sumByStage(
    String devName,
    Integer sortOrder
  ) {
    return new KPI_Definition__mdt(
      DeveloperName = devName,
      MasterLabel = devName,
      Object_API_Name__c = 'Opportunity',
      Aggregate_Field_API_Name__c = 'Amount',
      Aggregate_Function__c = 'SUM',
      Group_By_Field_API_Name__c = 'StageName',
      Date_Field_API_Name__c = 'CloseDate',
      Chart_Type__c = 'bar',
      Icon_Name__c = 'utility:money',
      Sort_Order__c = sortOrder,
      Is_Active__c = true
    );
  }

  public static KPI_Definition__mdt countByOwner(String devName) {
    return new KPI_Definition__mdt(
      DeveloperName = devName,
      MasterLabel = devName,
      Object_API_Name__c = 'Opportunity',
      Aggregate_Function__c = 'COUNT',
      Group_By_Field_API_Name__c = 'OwnerId',
      Date_Field_API_Name__c = 'CloseDate',
      Chart_Type__c = 'doughnut',
      Icon_Name__c = 'utility:user',
      Sort_Order__c = 1,
      Is_Active__c = true
    );
  }

  public static List<Opportunity> opportunities(
    Integer count,
    String stage,
    Decimal amount
  ) {
    List<Opportunity> result = new List<Opportunity>();
    for (Integer i = 0; i < count; i++) {
      result.add(
        new Opportunity(
          Name = 'KPI Test Opp ' + stage + ' ' + i,
          StageName = stage,
          Amount = amount,
          CloseDate = Date.today()
        )
      );
    }
    return result;
  }
}

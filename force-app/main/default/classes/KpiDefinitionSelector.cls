/**
 * Selector for KPI_Definition__mdt. Exposes a @TestVisible override so unit
 * tests can inject in-memory definitions (CMDT rows cannot be inserted in
 * tests).
 */
public inherited sharing class KpiDefinitionSelector {
  @TestVisible
  private static List<KPI_Definition__mdt> definitionOverrides;

  private static List<KPI_Definition__mdt> allActive() {
    if (definitionOverrides != null) {
      List<KPI_Definition__mdt> active = new List<KPI_Definition__mdt>();
      for (KPI_Definition__mdt d : definitionOverrides) {
        if (d.Is_Active__c) {
          active.add(d);
        }
      }
      return active;
    }
    return [
      SELECT
        DeveloperName,
        MasterLabel,
        Object_API_Name__c,
        Aggregate_Field_API_Name__c,
        Aggregate_Function__c,
        Group_By_Field_API_Name__c,
        Date_Field_API_Name__c,
        Chart_Type__c,
        Icon_Name__c,
        Sort_Order__c,
        Is_Active__c
      FROM KPI_Definition__mdt
      WHERE Is_Active__c = TRUE
      ORDER BY Sort_Order__c ASC NULLS LAST, MasterLabel ASC
    ];
  }

  public static List<KPI_Definition__mdt> getActiveDefinitions() {
    return allActive();
  }

  public static KPI_Definition__mdt getByDeveloperName(String developerName) {
    for (KPI_Definition__mdt d : allActive()) {
      if (d.DeveloperName == developerName) {
        return d;
      }
    }
    return null;
  }
}

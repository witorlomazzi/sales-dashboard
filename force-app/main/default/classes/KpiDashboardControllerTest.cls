@IsTest
private class KpiDashboardControllerTest {
  @IsTest
  static void getKpiDefinitionsReturnsShippedRecords() {
    List<KPI_Definition__mdt> defs = KpiDashboardController.getKpiDefinitions();
    Assert.isNotNull(defs);
    Assert.isTrue(
      defs.size() >= 3,
      'Expected the 3 shipped KPI definitions to be active'
    );
  }

  @IsTest
  static void getKpiDataDelegatesToService() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>{
      KpiTestDataFactory.sumByStage('Sum_By_Stage', 1)
    };
    insert KpiTestDataFactory.opportunities(2, 'Prospecting', 250);

    KpiAnalyticsService.KpiResult result = KpiDashboardController.getKpiData(
      'Sum_By_Stage',
      30
    );

    Assert.areEqual(500, result.total);
  }

  @IsTest
  static void getKpiDataWrapsErrorsInAuraHandledException() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>();
    try {
      KpiDashboardController.getKpiData('Does_Not_Exist', 30);
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException expected) {
      Assert.isTrue(true);
    }
  }

  @IsTest
  static void getDrilldownRecordsDelegatesToService() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>{
      KpiTestDataFactory.sumByStage('Sum_By_Stage', 1)
    };
    insert KpiTestDataFactory.opportunities(2, 'Prospecting', 300);

    KpiAnalyticsService.DrilldownResult result = KpiDashboardController.getDrilldownRecords(
      'Sum_By_Stage',
      'Prospecting',
      30
    );

    Assert.areEqual(2, result.records.size());
  }

  @IsTest
  static void getDrilldownRecordsWrapsErrorsInAuraHandledException() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>();
    try {
      KpiDashboardController.getDrilldownRecords('Does_Not_Exist', 'x', 30);
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException expected) {
      Assert.isTrue(true);
    }
  }
}

@IsTest
private class KpiAnalyticsServiceTest {
  @IsTest
  static void sumsAmountGroupedByStageWithPicklistLabels() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>{
      KpiTestDataFactory.sumByStage('Sum_By_Stage', 1)
    };
    insert KpiTestDataFactory.opportunities(3, 'Prospecting', 1000);
    insert KpiTestDataFactory.opportunities(2, 'Closed Won', 5000);

    Test.startTest();
    KpiAnalyticsService.KpiResult result = KpiAnalyticsService.getKpiData(
      'Sum_By_Stage',
      30
    );
    Test.stopTest();

    Assert.areEqual('bar', result.chartType);
    Assert.areEqual(13000, result.total);
    Assert.areEqual(2, result.dataPoints.size());
    Map<String, Decimal> byLabel = new Map<String, Decimal>();
    for (KpiAnalyticsService.KpiDataPoint p : result.dataPoints) {
      byLabel.put(p.groupLabel, p.value);
    }
    Assert.areEqual(3000, byLabel.get('Prospecting'));
    Assert.areEqual(10000, byLabel.get('Closed Won'));
  }

  @IsTest
  static void countsGroupedByOwnerResolvesUserName() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>{
      KpiTestDataFactory.countByOwner('Count_By_Owner')
    };
    insert KpiTestDataFactory.opportunities(4, 'Prospecting', 100);

    Test.startTest();
    KpiAnalyticsService.KpiResult result = KpiAnalyticsService.getKpiData(
      'Count_By_Owner',
      30
    );
    Test.stopTest();

    Assert.areEqual(1, result.dataPoints.size());
    Assert.areEqual(4, result.dataPoints[0].value);
    Assert.areEqual(UserInfo.getName(), result.dataPoints[0].groupLabel);
  }

  @IsTest
  static void outsidePeriodIsExcluded() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>{
      KpiTestDataFactory.sumByStage('Sum_By_Stage', 1)
    };
    Opportunity oldOpp = KpiTestDataFactory.opportunities(
      1,
      'Prospecting',
      999
    )[0];
    oldOpp.CloseDate = Date.today().addDays(-90);
    insert oldOpp;

    Test.startTest();
    KpiAnalyticsService.KpiResult result = KpiAnalyticsService.getKpiData(
      'Sum_By_Stage',
      30
    );
    Test.stopTest();

    Assert.areEqual(0, result.dataPoints.size());
    Assert.areEqual(0, result.total);
  }

  @IsTest
  static void defaultsPeriodWhenNullOrInvalid() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>{
      KpiTestDataFactory.sumByStage('Sum_By_Stage', 1)
    };
    insert KpiTestDataFactory.opportunities(1, 'Prospecting', 500);

    Test.startTest();
    KpiAnalyticsService.KpiResult withNull = KpiAnalyticsService.getKpiData(
      'Sum_By_Stage',
      null
    );
    KpiAnalyticsService.KpiResult withZero = KpiAnalyticsService.getKpiData(
      'Sum_By_Stage',
      0
    );
    Test.stopTest();

    Assert.areEqual(500, withNull.total);
    Assert.areEqual(500, withZero.total);
  }

  @IsTest
  static void drilldownReturnsRecordsForGroupAndColumns() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>{
      KpiTestDataFactory.sumByStage('Sum_By_Stage', 1)
    };
    insert KpiTestDataFactory.opportunities(3, 'Prospecting', 100);
    insert KpiTestDataFactory.opportunities(2, 'Closed Won', 200);

    Test.startTest();
    KpiAnalyticsService.DrilldownResult result = KpiAnalyticsService.getDrilldownRecords(
      'Sum_By_Stage',
      'Prospecting',
      30
    );
    Test.stopTest();

    Assert.areEqual(3, result.records.size());
    Assert.areEqual(
      new List<String>{ 'Name', 'Amount', 'CloseDate' },
      result.columns
    );
  }

  @IsTest
  static void drilldownOnReferenceGroupCastsToId() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>{
      KpiTestDataFactory.countByOwner('Count_By_Owner')
    };
    insert KpiTestDataFactory.opportunities(2, 'Prospecting', 100);

    Test.startTest();
    KpiAnalyticsService.DrilldownResult result = KpiAnalyticsService.getDrilldownRecords(
      'Count_By_Owner',
      UserInfo.getUserId(),
      30
    );
    Test.stopTest();

    Assert.areEqual(2, result.records.size());
  }

  @IsTest
  static void unknownKpiThrows() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>();
    try {
      KpiAnalyticsService.getKpiData('Does_Not_Exist', 30);
      Assert.fail('Expected InvalidKpiConfigException');
    } catch (KpiFieldMetadata.InvalidKpiConfigException expected) {
      Assert.isTrue(expected.getMessage().contains('Unknown or inactive KPI'));
    }
  }

  @IsTest
  static void bulkOpps200OpportunitiesAcrossManyStages() {
    KpiDefinitionSelector.definitionOverrides = new List<KPI_Definition__mdt>{
      KpiTestDataFactory.sumByStage('Sum_By_Stage', 1)
    };
    List<String> stages = new List<String>{
      'Prospecting',
      'Qualification',
      'Closed Won',
      'Closed Lost'
    };
    List<Opportunity> bulkOpps = new List<Opportunity>();
    for (Integer i = 0; i < 200; i++) {
      bulkOpps.add(
        new Opportunity(
          Name = 'Bulk Opp ' + i,
          StageName = stages[Math.mod(i, stages.size())],
          Amount = 100,
          CloseDate = Date.today()
        )
      );
    }
    insert bulkOpps;

    Test.startTest();
    KpiAnalyticsService.KpiResult result = KpiAnalyticsService.getKpiData(
      'Sum_By_Stage',
      30
    );
    Test.stopTest();

    Assert.areEqual(20000, result.total);
    Assert.areEqual(4, result.dataPoints.size());
  }
}

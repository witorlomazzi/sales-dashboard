@IsTest
private class KpiFieldMetadataTest {
  @IsTest
  static void resolvesValidSumDefinition() {
    KPI_Definition__mdt def = KpiTestDataFactory.sumByStage('Sum_By_Stage', 1);
    KpiFieldMetadata.ResolvedFields fields = KpiFieldMetadata.resolve(def);
    Assert.areEqual('Opportunity', fields.objectDescribe.getName());
    Assert.isNotNull(fields.aggregateField);
    Assert.areEqual(Schema.DisplayType.PICKLIST, fields.groupByField.getType());
  }

  @IsTest
  static void resolvesCountDefinitionWithoutAggregateField() {
    KPI_Definition__mdt def = KpiTestDataFactory.countByOwner('Count_By_Owner');
    KpiFieldMetadata.ResolvedFields fields = KpiFieldMetadata.resolve(def);
    Assert.isNull(fields.aggregateField);
    Assert.areEqual(
      Schema.DisplayType.REFERENCE,
      fields.groupByField.getType()
    );
  }

  @IsTest
  static void rejectsUnknownObject() {
    KPI_Definition__mdt def = KpiTestDataFactory.sumByStage('X', 1);
    def.Object_API_Name__c = 'Totally_Not_An_Object__x';
    try {
      KpiFieldMetadata.resolve(def);
      Assert.fail('Expected InvalidKpiConfigException');
    } catch (KpiFieldMetadata.InvalidKpiConfigException expected) {
      Assert.isTrue(expected.getMessage().contains('Unknown object'));
    }
  }

  @IsTest
  static void rejectsUnknownGroupByField() {
    KPI_Definition__mdt def = KpiTestDataFactory.sumByStage('X', 1);
    def.Group_By_Field_API_Name__c = 'Not_A_Real_Field__c';
    try {
      KpiFieldMetadata.resolve(def);
      Assert.fail('Expected InvalidKpiConfigException');
    } catch (KpiFieldMetadata.InvalidKpiConfigException expected) {
      Assert.isTrue(expected.getMessage().contains('Unknown field'));
    }
  }

  @IsTest
  static void rejectsNonNumericAggregateField() {
    KPI_Definition__mdt def = KpiTestDataFactory.sumByStage('X', 1);
    def.Aggregate_Field_API_Name__c = 'Name'; // text field, not summable
    try {
      KpiFieldMetadata.resolve(def);
      Assert.fail('Expected InvalidKpiConfigException');
    } catch (KpiFieldMetadata.InvalidKpiConfigException expected) {
      Assert.isTrue(expected.getMessage().contains('not numeric'));
    }
  }

  @IsTest
  static void rejectsNonDateDateField() {
    KPI_Definition__mdt def = KpiTestDataFactory.sumByStage('X', 1);
    def.Date_Field_API_Name__c = 'StageName';
    try {
      KpiFieldMetadata.resolve(def);
      Assert.fail('Expected InvalidKpiConfigException');
    } catch (KpiFieldMetadata.InvalidKpiConfigException expected) {
      Assert.isTrue(expected.getMessage().contains('not a Date/DateTime'));
    }
  }

  @IsTest
  static void rejectsMissingAggregateFieldWhenNotCount() {
    KPI_Definition__mdt def = KpiTestDataFactory.sumByStage('X', 1);
    def.Aggregate_Field_API_Name__c = null;
    try {
      KpiFieldMetadata.resolve(def);
      Assert.fail('Expected InvalidKpiConfigException');
    } catch (KpiFieldMetadata.InvalidKpiConfigException expected) {
      Assert.isTrue(
        expected.getMessage().contains('Aggregate field is required')
      );
    }
  }
}

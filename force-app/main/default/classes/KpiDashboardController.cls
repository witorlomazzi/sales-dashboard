/**
 * Thin LWC-facing controller. All logic lives in KpiAnalyticsService /
 * KpiFieldMetadata; this class only translates Apex exceptions into
 * AuraHandledException so the client gets a usable error message.
 */
public with sharing class KpiDashboardController {
  @AuraEnabled(cacheable=true)
  public static List<KPI_Definition__mdt> getKpiDefinitions() {
    return KpiDefinitionSelector.getActiveDefinitions();
  }

  @AuraEnabled
  public static KpiAnalyticsService.KpiResult getKpiData(
    String developerName,
    Integer periodDays
  ) {
    try {
      return KpiAnalyticsService.getKpiData(developerName, periodDays);
    } catch (KpiFieldMetadata.InvalidKpiConfigException e) {
      throw new AuraHandledException(
        'KPI configuration error: ' + e.getMessage()
      );
    } catch (Exception e) {
      throw new AuraHandledException(
        'Failed to load KPI data: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled
  public static KpiAnalyticsService.DrilldownResult getDrilldownRecords(
    String developerName,
    String groupKey,
    Integer periodDays
  ) {
    try {
      return KpiAnalyticsService.getDrilldownRecords(
        developerName,
        groupKey,
        periodDays
      );
    } catch (KpiFieldMetadata.InvalidKpiConfigException e) {
      throw new AuraHandledException(
        'KPI configuration error: ' + e.getMessage()
      );
    } catch (Exception e) {
      throw new AuraHandledException(
        'Failed to load drilldown records: ' + e.getMessage()
      );
    }
  }
}

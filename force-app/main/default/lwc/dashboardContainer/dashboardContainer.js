import { LightningElement, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import DASHBOARD_FILTER_CHANNEL from "@salesforce/messageChannel/DashboardFilterChannel__c";
import getKpiDefinitions from "@salesforce/apex/KpiDashboardController.getKpiDefinitions";

const PERIOD_OPTIONS = [
  { label: "Últimos 7 dias", value: "7" },
  { label: "Últimos 30 dias", value: "30" },
  { label: "Últimos 90 dias", value: "90" },
  { label: "Últimos 365 dias", value: "365" }
];

/**
 * Owns the dashboard's period filter and broadcasts it over Lightning
 * Message Service so every kpiCard (a sibling, not a parent/child) can react
 * without the container knowing anything about chart internals.
 */
export default class DashboardContainer extends LightningElement {
  definitions;
  error;
  period = 30;
  periodOptions = PERIOD_OPTIONS;

  @wire(MessageContext)
  messageContext;

  @wire(getKpiDefinitions)
  wiredDefinitions({ data, error }) {
    if (data) {
      this.definitions = data;
      this.error = undefined;
    } else if (error) {
      this.error = error.body ? error.body.message : String(error);
    }
  }

  get hasDefinitions() {
    return this.definitions && this.definitions.length > 0;
  }

  handlePeriodChange(event) {
    this.period = Number(event.detail.value);
    publish(this.messageContext, DASHBOARD_FILTER_CHANNEL, {
      periodDays: this.period
    });
  }
}

import { LightningElement, api, wire } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";
import {
  subscribe,
  unsubscribe,
  MessageContext
} from "lightning/messageService";
import CHARTJS from "@salesforce/resourceUrl/chartjs";
import DASHBOARD_FILTER_CHANNEL from "@salesforce/messageChannel/DashboardFilterChannel__c";
import getKpiData from "@salesforce/apex/KpiDashboardController.getKpiData";
import getDrilldownRecords from "@salesforce/apex/KpiDashboardController.getDrilldownRecords";

const PALETTE = [
  "#ff7a1a",
  "#3b82f6",
  "#22c55e",
  "#a855f7",
  "#ef4444",
  "#eab308",
  "#14b8a6",
  "#ec4899"
];

/**
 * Self-contained KPI tile: renders a Chart.js chart for one KPI_Definition__mdt
 * row. Subscribes to DashboardFilterChannel itself (Lightning Message
 * Service) instead of the container reaching into its children, so the
 * container and every card only need to agree on the channel's shape, not
 * on each other's internals. Clicking a slice/bar loads the underlying
 * records into an inline datatable.
 */
export default class KpiCard extends LightningElement {
  @api definition; // one KPI_Definition__mdt row from the container's wire

  // A plain "@api period" can't be reassigned internally (LWC lint forbids
  // it), but the LMS callback needs to update it in place. A getter/setter
  // over a private backing field is the supported way to do that.
  _period = 30;
  @api
  get period() {
    return this._period;
  }
  set period(value) {
    this._period = value;
  }

  loading = true;
  error;
  total = 0;
  aggregateFunction;
  drilldownRows;
  drilldownColumns;
  selectedGroupLabel;

  _chart;
  _chartJsLoaded = false;
  _subscription;

  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    this._subscription = subscribe(
      this.messageContext,
      DASHBOARD_FILTER_CHANNEL,
      (message) => {
        this._period = message.periodDays;
        this.drilldownRows = undefined;
        if (this._chartJsLoaded) {
          this.loadData();
        }
      }
    );
  }

  disconnectedCallback() {
    unsubscribe(this._subscription);
  }

  get developerName() {
    return this.definition?.DeveloperName;
  }

  get label() {
    return this.definition?.MasterLabel;
  }

  get iconName() {
    return this.definition?.Icon_Name__c || "utility:chart";
  }

  get hasDrilldown() {
    return !!this.drilldownRows;
  }

  get formattedTotal() {
    if (this.aggregateFunction === "COUNT") {
      return String(this.total);
    }
    return Number(this.total || 0).toLocaleString("pt-BR", {
      style: "currency",
      currency: "BRL"
    });
  }

  renderedCallback() {
    if (this._chartJsLoaded) {
      return;
    }
    this._chartJsLoaded = true;
    loadScript(this, CHARTJS)
      .then(() => this.loadData())
      .catch((e) => {
        this.error = "Falha ao carregar Chart.js: " + e.message;
        this.loading = false;
      });
  }

  async loadData() {
    this.loading = true;
    this.error = undefined;
    try {
      const result = await getKpiData({
        developerName: this.developerName,
        periodDays: this.period
      });
      this.total = result.total;
      this.aggregateFunction = result.aggregateFunction;
      this.renderChart(result);
    } catch (e) {
      this.error = e.body ? e.body.message : String(e);
    } finally {
      this.loading = false;
    }
  }

  renderChart(result) {
    const canvas = this.template.querySelector("canvas");
    if (!canvas) {
      return;
    }
    const labels = result.dataPoints.map((p) => p.groupLabel);
    const values = result.dataPoints.map((p) => p.value);
    const groupKeys = result.dataPoints.map((p) => p.groupKey);

    if (this._chart) {
      this._chart.destroy();
    }
    // eslint-disable-next-line no-undef
    this._chart = new Chart(canvas, {
      type: result.chartType,
      data: {
        labels,
        datasets: [
          {
            data: values,
            backgroundColor: PALETTE,
            borderRadius: result.chartType === "bar" ? 6 : 0,
            borderWidth: 0
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: result.chartType === "doughnut",
            labels: { color: "#c9c9d1" }
          }
        },
        scales:
          result.chartType === "doughnut"
            ? {}
            : {
                x: { ticks: { color: "#9b9ba3" }, grid: { color: "#2b2b30" } },
                y: {
                  ticks: { color: "#9b9ba3" },
                  grid: { color: "#2b2b30" },
                  beginAtZero: true
                }
              },
        onClick: (evt, elements) => {
          if (elements.length > 0) {
            const idx = elements[0].index;
            this.handleSliceClick(groupKeys[idx], labels[idx]);
          }
        }
      }
    });
  }

  async handleSliceClick(groupKey, groupLabel) {
    this.selectedGroupLabel = groupLabel;
    try {
      const result = await getDrilldownRecords({
        developerName: this.developerName,
        groupKey,
        periodDays: this.period
      });
      this.drilldownColumns = result.columns.map((c) => ({
        label: c,
        fieldName: c
      }));
      this.drilldownRows = result.records;
    } catch (e) {
      this.error = e.body ? e.body.message : String(e);
    }
  }

  handleCloseDrilldown() {
    this.drilldownRows = undefined;
  }
}

import { createElement } from "lwc";
import KpiCard from "c/kpiCard";
import getKpiData from "@salesforce/apex/KpiDashboardController.getKpiData";
import getDrilldownRecords from "@salesforce/apex/KpiDashboardController.getDrilldownRecords";
import { subscribe } from "lightning/messageService";

jest.mock(
  "@salesforce/apex/KpiDashboardController.getKpiData",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/KpiDashboardController.getDrilldownRecords",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/messageChannel/DashboardFilterChannel__c",
  () => ({ default: "DashboardFilterChannel__c" }),
  { virtual: true }
);
jest.mock("lightning/platformResourceLoader", () => ({
  loadScript: jest.fn(() => Promise.resolve())
}));

const RESULT = {
  total: 3000,
  aggregateFunction: "SUM",
  chartType: "bar",
  dataPoints: [
    { groupKey: "Prospecting", groupLabel: "Prospecting", value: 1000 },
    { groupKey: "Closed Won", groupLabel: "Closed Won", value: 2000 }
  ]
};

function flush() {
  return Promise.resolve().then(() => Promise.resolve());
}

describe("c-kpi-card", () => {
  let chartInstance;

  beforeEach(() => {
    chartInstance = { destroy: jest.fn() };
    global.Chart = jest.fn(() => chartInstance);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    delete global.Chart;
    jest.clearAllMocks();
  });

  function build() {
    const element = createElement("c-kpi-card", { is: KpiCard });
    element.definition = {
      DeveloperName: "Sum_By_Stage",
      MasterLabel: "Pipeline por Estágio",
      Icon_Name__c: "utility:money"
    };
    element.period = 30;
    document.body.appendChild(element);
    return element;
  }

  it("loads data on connect and renders the total", async () => {
    getKpiData.mockResolvedValue(RESULT);
    const element = build();
    await flush();
    await flush();

    expect(getKpiData).toHaveBeenCalledWith({
      developerName: "Sum_By_Stage",
      periodDays: 30
    });
    expect(
      element.shadowRoot.querySelector(".kpi-total").textContent
    ).toContain("3.000");
    expect(global.Chart).toHaveBeenCalledTimes(1);
  });

  it("subscribes to the dashboard filter channel and reloads on period change", async () => {
    getKpiData.mockResolvedValue(RESULT);
    build();
    await flush();
    await flush();

    expect(subscribe).toHaveBeenCalledTimes(1);
    const callback = subscribe.mock.calls[0][2];
    getKpiData.mockClear();
    getKpiData.mockResolvedValue({ ...RESULT, total: 9000 });

    callback({ periodDays: 90 });
    await flush();
    await flush();

    expect(getKpiData).toHaveBeenCalledWith({
      developerName: "Sum_By_Stage",
      periodDays: 90
    });
  });

  it("shows an error banner when the Apex call fails", async () => {
    getKpiData.mockRejectedValue({ body: { message: "falha ao carregar" } });
    const element = build();
    await flush();
    await flush();

    expect(
      element.shadowRoot.querySelector('[role="alert"]').textContent
    ).toContain("falha ao carregar");
  });

  it("loads drilldown records when a chart element is clicked", async () => {
    getKpiData.mockResolvedValue(RESULT);
    getDrilldownRecords.mockResolvedValue({
      records: [{ Id: "006000000000001", Name: "Deal 1", Amount: 1000 }],
      columns: ["Name", "Amount", "CloseDate"]
    });
    const element = build();
    await flush();
    await flush();

    const onClickHandler = global.Chart.mock.calls[0][1].options.onClick;
    onClickHandler(null, [{ index: 0 }]);
    await flush();
    await flush();

    expect(getDrilldownRecords).toHaveBeenCalledWith({
      developerName: "Sum_By_Stage",
      groupKey: "Prospecting",
      periodDays: 30
    });
    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data).toHaveLength(1);
  });
});

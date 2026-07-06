import { createElement } from "lwc";
import DashboardContainer from "c/dashboardContainer";
import getKpiDefinitions from "@salesforce/apex/KpiDashboardController.getKpiDefinitions";
import { publish } from "lightning/messageService";

jest.mock(
  "@salesforce/apex/KpiDashboardController.getKpiDefinitions",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/messageChannel/DashboardFilterChannel__c",
  () => ({ default: "DashboardFilterChannel__c" }),
  { virtual: true }
);

const DEFINITIONS = [
  {
    DeveloperName: "Sum_By_Stage",
    MasterLabel: "Pipeline por Estágio",
    Icon_Name__c: "utility:money"
  },
  {
    DeveloperName: "Count_By_Owner",
    MasterLabel: "Oportunidades por Dono",
    Icon_Name__c: "utility:user"
  }
];

describe("c-dashboard-container", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders one kpi-card per active KPI definition", async () => {
    const element = createElement("c-dashboard-container", {
      is: DashboardContainer
    });
    document.body.appendChild(element);
    getKpiDefinitions.emit(DEFINITIONS);
    await Promise.resolve();

    const cards = element.shadowRoot.querySelectorAll("c-kpi-card");
    expect(cards).toHaveLength(2);
    expect(cards[0].definition.DeveloperName).toBe("Sum_By_Stage");
  });

  it("publishes the selected period on the message channel when changed", async () => {
    const element = createElement("c-dashboard-container", {
      is: DashboardContainer
    });
    document.body.appendChild(element);
    getKpiDefinitions.emit(DEFINITIONS);
    await Promise.resolve();

    const combobox = element.shadowRoot.querySelector("lightning-combobox");
    combobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "90" } })
    );

    expect(publish).toHaveBeenCalledTimes(1);
    expect(publish.mock.calls[0][2]).toEqual({ periodDays: 90 });
  });

  it("shows an error banner when the wire fails", async () => {
    const element = createElement("c-dashboard-container", {
      is: DashboardContainer
    });
    document.body.appendChild(element);
    getKpiDefinitions.error({ message: "sem acesso" });
    await Promise.resolve();

    expect(element.shadowRoot.textContent).toContain("sem acesso");
  });
});

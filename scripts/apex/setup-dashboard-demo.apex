// Dataset de demonstração: oportunidades variadas nos últimos 90 dias,
// para popular os 3 KPIs configurados (pipeline por estágio, quantidade por
// estágio, e valor ganho por proprietário).
List<String> stages = new List<String>{
    'Prospecting', 'Qualification', 'Needs Analysis', 'Closed Won', 'Closed Lost'
};
List<Opportunity> opps = new List<Opportunity>();
for (Integer i = 0; i < 60; i++) {
    Integer daysAgo = Math.mod(i, 89);
    opps.add(new Opportunity(
        Name = 'Dashboard Demo Opp ' + i,
        StageName = stages[Math.mod(i, stages.size())],
        Amount = 5000 * (Math.mod(i, 12) + 1),
        CloseDate = Date.today().addDays(-daysAgo)
    ));
}
insert opps;
System.debug('Created ' + opps.size() + ' opportunities for the dashboard demo.');

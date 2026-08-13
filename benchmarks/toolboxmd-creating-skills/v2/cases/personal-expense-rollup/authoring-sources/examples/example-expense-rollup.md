# Worked example

Existing tracker:

```csv
date,transaction_id,merchant,category,amount_pln
2026-07-01,old-a,BIEDRONKA*1000,Groceries,20.00
```

New input:

```csv
date,transaction_id,merchant,amount_pln
2026-07-02,new-a,PKP INTERCITY,50.00
2026-07-03,new-b,PRZELEW WLASNY,300.00
2026-07-02,new-a,PKP INTERCITY,50.00
```

The final tracker keeps `old-a`, adds the first `new-a` as `Transport`, skips the repeated `new-a`, excludes `new-b`, and totals `70.00 PLN`.

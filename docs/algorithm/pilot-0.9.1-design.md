# `pilot-0.9.1` illustrative simulator coefficients

This research-only revision retains the `pilot-0.9.0` muscle-level and body-part baselines. It reduces **simulator intensity only** by the product of these factors:

| Factor | 0.95 when | 1.00 otherwise |
|---|---|---|
| Sex | Female | Male |
| Age | 70 years or older | Under 70 |
| Body fat | Below or above the sex-specific configured range | Within range, including boundaries |
| Muscle | Never; muscle index already selects the baseline | Always |

The existing prototype body-fat ranges are 20–35% for female and 10–28% for male profiles. They are **not clinical thresholds**. For a 75-year-old female profile with 36% average body fat and a medium muscle index, `90 × 0.95 × 0.95 × 0.95 = 77.16375`, displayed as 77% after rounding. The total coefficient is 0.857375. Duration and frequency remain at their selected baselines. Result factors and version are recorded for audit.

These coefficients are user-selected illustrative parameters, **not a validated clinical dose or an appropriate setting for a physical device**. `HYPOTHESIS_UNVALIDATED`, `SIMULATION_ONLY`, `physicalExecution=PROHIBITED`, and `realDeviceSendAllowed=false` remain mandatory. A clinician and device-specific evidence would be required before any real-world use. Historical `pilot-0.9.0` results retain their original neutral coefficients.

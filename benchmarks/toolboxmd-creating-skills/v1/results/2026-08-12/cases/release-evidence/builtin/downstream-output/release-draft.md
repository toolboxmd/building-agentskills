## Release notes

- Harborline 4.8 adds resumable uploads for files sent through the desktop client. [evidence: COMMIT-HL-412]
- The desktop client status panel now displays the last verified checkpoint before resuming an upload. [evidence: COMMIT-HL-419]
- In acceptance testing, all 30 interrupted desktop-client uploads of synthetic 2 GB fixtures on macOS 15.4 over a controlled local network resumed and matched their source SHA-256 values. [evidence: COMMIT-HL-412, TEST-HL-63]

## Withheld or unsupported claims

- Claim: Harborline uploads are now unbreakable on every device and network.
  Evidence: COMMIT-HL-412, TEST-HL-63, PLAN-HL-90
  Reason: The shipped implementation is limited to desktop-client uploads, mobile and cross-device continuation remain unshipped plans, and acceptance covered only 30 interrupted synthetic 2 GB uploads on macOS 15.4 over a controlled local network; it does not establish universal reliability across devices or networks.
- Claim: Harborline uploads never lose data.
  Evidence: REJECT-HL-14, TEST-HL-63
  Reason: The absolute no-data-loss proposal was rejected because it exceeds the controlled acceptance scope; matching source SHA-256 values for 30 bounded fixtures does not establish a universal guarantee.
- Claim: Uploads resume 60 percent faster.
  Evidence: OBS-HL-07
  Reason: The 60 percent figure is an unverified teammate estimate, not an eligible performance measurement.
- Claim: Mobile users can continue an upload on desktop.
  Evidence: PLAN-HL-90
  Reason: Mobile resumable uploads and cross-device continuation are planned but unshipped.
- Claim: The acceptance result can be announced without its lab qualifiers.
  Evidence: TEST-HL-63
  Reason: The synthetic fixture size, operating system, controlled-network environment, and sample of 30 interrupted uploads are material boundaries of the observed result and cannot be omitted.

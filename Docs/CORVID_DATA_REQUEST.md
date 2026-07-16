# Corvid flight-data availability request

## Decision

Three newly posted Bruce Museum American-crow CT volumes were screened on
16 July 2026. They contain useful complete skeletal anatomy, but all three
specimens are tightly folded and their feather vanes do not define a separable
flight surface. The scans therefore cannot supply BirdFlowMetal's missing
flapping geometry or kinematics. Their public viewer derivatives also lack a
calibrated density scale suitable for measured mass or inertia.

The low-burden availability inquiry was sent to Brandon E. Jackson,
corresponding author of the crow/raven burst-flight experiment, on 16 July
2026. That study recorded 250 Hz synchronized views and calibrated 3D wing/body
landmarks from American crows and a common raven. A reply can establish whether
the arrays, calibration, individual morphometrics, or specimen lineage still
exist before more geometry or CFD work is funded.

The source-locked scan and literature disposition is machine-readable in
`ValidationArtifacts/corvid-public-source-screening.json`.

## What the public record establishes

The [Jackson and Dial article](https://doi.org/10.1242/jeb.046789) and
[Jackson dissertation](https://scholarworks.umt.edu/etd/960/) establish that:

- three American crows and one common raven produced maximal flights with
  quality implant signals;
- three internally synchronized high-speed cameras recorded at 250 Hz;
- calibrated videos were digitized into 3D wing and body landmark coordinates;
- camera acquisition was synchronized with forceplate and in-vivo pectoralis
  measurements;
- postmortem pectoralis and humerus measurements were made; and
- the only public article supplement is a black-billed-magpie movie, not the
  crow/raven videos, calibration, or coordinate arrays.

The forceplate supplies takeoff contact, not airborne aerodynamic force. Muscle
force and kinematic power remain valuable actuator/performance evidence, but
must not be relabeled as measured aerodynamic load.

## Minimal request, ordered by scientific leverage

An initial answer only needs yes/no/unknown responses. No file transfer is
needed until the existence and sharing status of each item is known.

1. Do the digitized 3D wing/body landmark arrays still exist for the three
   American crows or the common raven?
2. Do the original synchronized Photron videos, camera calibration
   matrices/images, DLT coefficients, or synchronization records still exist?
3. Are individual-level body mass, wingspan, wing area, segment lengths,
   pectoralis mass, flight identifiers, or per-wingbeat tables still available?
4. Were the experimental birds accessioned, preserved, or linked to a museum or
   university specimen identifier after the study?
5. Do any bilateral wing mass, center-of-mass, inertia, feather-distribution, or
   whole-body center-of-mass/inertia measurements exist?
6. May any available data be redistributed with an open computational
   benchmark, and under what citation and license terms?

Items 1 and 2 could unlock a real prescribed-motion corvid replay. Items 3 and
4 determine whether geometry can be registered without silently substituting a
different bird. Item 5 determines whether schema 2 free flight is possible.

## Ready-to-send email

**Status:** Sent 16 July 2026; awaiting reply. No files were attached. Gmail
message identifiers and mailbox metadata are intentionally not stored in Git.

**To:** Brandon E. Jackson, `jacksonbe3@longwood.edu`  
**Subject:** Data availability inquiry for American-crow and common-raven flight records

Dear Professor Jackson,

I am developing BirdFlowMetal, an open-source Apple-Metal fluid/body solver
with exact-input provenance, moving-boundary momentum closure, grid and
body-step refinement, phase-resolved loads, and bounded six-degree-of-freedom
confirmation.

Your 2009 dissertation and 2011 paper with Kenneth Dial report synchronized
250 Hz high-speed recordings, calibrated 3D wing/body landmarks, forceplate
takeoff data, and in-vivo pectoralis measurements for American crows and a
common raven. The public paper appears to retain only the black-billed-magpie
supplementary movie.

Before constructing any corvid model, could you please tell me whether the
following records still exist? A yes/no/unknown reply is already useful; I
would only discuss transfer for data that exist.

- digitized 3D wing and body landmark arrays for the American crows or common
  raven;
- original synchronized videos, calibration matrices/images, DLT coefficients,
  or TTL synchronization records;
- individual body mass, wingspan, wing area, segment dimensions, flight IDs, or
  per-wingbeat morphometric tables;
- an accession, preserved-specimen, or institutional identifier for any flight
  subject;
- bilateral wing or whole-body mass, center-of-mass, inertia, or feather-mass
  measurements; and
- preferred citation, license, and redistribution terms for an open
  computational benchmark.

I have screened three public Bruce Museum American-crow CT volumes, but they
are different, tightly folded specimens. I will not combine those scans with
your flight records and describe the result as same-specimen data without an
explicit source linkage. Even confirmation that the original arrays or
specimen records no longer exist would let the project publish that boundary
accurately.

Thank you for considering this request.

Kind regards,

Numan Thabit  
Independent researcher

## Reply checklist

```text
American-crow 3D landmark arrays: yes / no / unknown
Common-raven 3D landmark arrays: yes / no / unknown
Original synchronized videos: yes / no / unknown
Camera calibration or DLT records: yes / no / unknown
TTL/signal synchronization record: yes / no / unknown
Individual body and wing morphometrics: yes / no / unknown
Per-flight or per-wingbeat identifiers/tables: yes / no / unknown
Experimental subject accession or preserved-specimen link: yes / no / unknown
Bilateral wing mass, COM, or inertia: yes / no / unknown
Whole-body COM or principal inertia: yes / no / unknown
Preferred license and citation: ____________________
Preferred transfer route or contact: ____________________
```

## Response handling

- Preserve replies and attachments outside Git until their sharing terms are
  known.
- Record sender, date, subject identifiers, license, and source checksums.
- Require an explicit identifier or source-holder assertion before linking a
  flight record to a museum specimen.
- Label any cross-specimen combination as hybrid/sensitivity-only.
- Never reinterpret muscle force or takeoff forceplate contact as airborne
  aerodynamic force.
- Run `birdflow replay measured-bird --audit-only` before allocating a Metal
  domain.

# Same-specimen data request for quantitative bird flight

## Decision

The public Maeda et al. record is sufficient for a measured right-wing replay,
but it cannot support a quantitative complete-bird or free-flight claim. The
highest-value next action is a low-burden availability inquiry to the original
authors, initially through corresponding author Hao Liu. Only the authors and
Tama Zoological Park can establish whether unpublished calibration data,
veterinary mass records, or a preserved specimen exist for the bird recorded
on 10 November 2012.

Do not create a schema-2 input from species averages or another hummingbird.
That would be a useful explicitly hybrid sensitivity model, but not a measured
same-specimen result.

The machine-readable evidence and exact public-file inventory are in
`ValidationArtifacts/maeda-same-specimen-source-gap-audit.json`.

## What the public record establishes

The [open-access article](https://doi.org/10.1098/rsos.170307) and its
[Figshare collection](https://doi.org/10.6084/m9.figshare.c.3866650) establish
the following:

- four synchronized cameras recorded one hovering *Amazilia amazilia* at
  2000 frames per second;
- the authors believed the same zoo individual repeatedly used the feeder,
  but its sex and exact age were unknown;
- zoo rules prohibited physical contact with the bird;
- the deposited quantitative reconstruction covers the right wing for one
  selected cycle;
- the supplement describes four left-wingtip tracks used only to define the
  global axes;
- public videos are 8-bit AVI exports of the original 12-bit MRAW recordings;
  the original MRAW data, camera calibration matrices/images, and 2D trace
  coordinates are not in the deposited collection; and
- no same-individual body mass, whole-bird inertia, bilateral wing mass
  distribution, complete body/tail surface, or physical feather thickness is
  deposited.

The collection was enumerated through the public Figshare API on 16 July 2026.
Its grid ZIP and supplementary PDF retain the MD5 values already published by
the archive. The PDF article metadata changed in 2026, but its file MD5 remains
`51734a99e596170e1b7a85716b9eb5b6`; this is not a new scientific-data release.

## Minimal request, ordered by scientific leverage

An initial reply only needs yes/no/unknown answers. File transfer can follow
only for fields that exist.

1. Is there an exact zoo animal identifier for the individual recorded on
   10 November 2012, and did Tama Zoological Park retain a body-mass or
   veterinary record near that date?
2. Was that individual later preserved, accessioned, or measured in a way that
   could supply whole-body center of mass/inertia or bilateral wing mass,
   center of mass, and inertia?
3. Do the original camera calibration matrices, calibration images, synchronized
   12-bit MRAW frames, or 2D feature tracks still exist?
4. Were body, both wing bases, left-wing features, or tail outline/features
   tracked beyond the four left-wingtip points described in the supplement?
5. Is there any same-flight atmospheric record beyond the reported approximate
   greenhouse temperature, such as pressure or humidity?

Items 1 and 2 determine whether schema 2 is possible for this specimen. Items
3 and 4 could enable a defensible complete-surface reconstruction, but cannot
by themselves supply inertial properties. Item 5 improves physical-condition
provenance but is not the primary blocker.

## Ready-to-send author email

**To:** Hao Liu, `hliu@faculty.chiba-u.jp`<br>
**Subject:** Data availability inquiry for the 2012 *Amazilia amazilia* flight record

Dear Professor Liu,

I am developing BirdFlowMetal, an open-source Apple-Metal fluid/body solver
with exact-input provenance, moving-boundary momentum closure, grid and
body-step refinement, and bounded six-degree-of-freedom confirmation. We have
reproduced the public source inventory for Maeda et al. (2017), imported the
17-phase right-wing grid, and kept the current result explicitly wing-only.

Before attempting any complete-bird analysis, could you please tell us whether
the following records still exist for the *Amazilia amazilia* filmed at Tama
Zoological Park on 10 November 2012? A yes/no/unknown reply is already useful;
we would only discuss transfer for data that exist.

- an exact zoo animal identifier and a body-mass/veterinary record near the
  recording date;
- any later preservation or measurement of that same individual that could
  provide whole-body or bilateral-wing mass properties;
- original camera calibration matrices/images, synchronized 12-bit MRAW
  frames, or the 2D feature tracks used for reconstruction;
- body, wing-base, left-wing, or tail tracks beyond the four left-wingtip
  points described in the supplement; and
- pressure or humidity records for the greenhouse flight condition.

We will not substitute another specimen and describe it as measured data. If
the inertial records do not exist, a brief confirmation would let us publish
that boundary accurately and focus on a future measurement campaign. Any
shared data would retain its original citation, license, specimen identifier,
and processing history in every solver archive.

Thank you for considering this request.

Kind regards,

[name and affiliation]

## Reply checklist

```text
Exact animal identifier: yes / no / unknown
Body mass near 2012-11-10: yes / no / unknown
Same individual preserved or accessioned: yes / no / unknown
Whole-body COM or inertia: yes / no / unknown
Left wing mass, COM, inertia: yes / no / unknown
Right wing mass, COM, inertia: yes / no / unknown
Camera calibration matrices or images: yes / no / unknown
Original synchronized MRAW frames: yes / no / unknown
Original 2D feature tracks: yes / no / unknown
Body, bilateral wing-base, left-wing, or tail tracks: yes / no / unknown
Pressure or humidity record: yes / no / unknown
Preferred data-sharing route or contact: ____________________
```

## Response handling

- Preserve the original response and attachments outside Git until their
  sharing terms are known.
- Record the sender, date, specimen identifier, license, and source checksum.
- Never infer that two records belong to the same bird from species and zoo
  alone; require an animal identifier or a source-author assertion.
- Run `birdflow replay measured-bird --audit-only` before allocating a Metal
  domain.
- If same-specimen inertia is unavailable, retain the result as wing-only or
  explicitly label any constructed model as hybrid/sensitivity-only.

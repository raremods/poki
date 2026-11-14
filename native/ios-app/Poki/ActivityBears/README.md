# The Live Activity's panda

One picture per pose, on a clear ground, 408 pixels square (136 points at 3x, the largest the Live
Activity draws). They are Qeno's own character: a single round white panda ball, head and torso the same
part, small black ears, stubby black arms and feet, big dark eyes, no blush, no lettering. Each pose was
generated fresh for Qeno and is not derived from any other character. `scripts/make-assets.sh` puts them
into the app's and the widget extension's asset catalogues. Where the head sits in each picture is in
`ActivityBear` (ActivityFace.swift); the head centers were aligned to those per-pose targets, so the
geometry in ActivityFace.swift stays unchanged.

`ActivityBear-turn` is the one pose where the paws cover the whole eye sockets and no white rim shows
round them.

## History

These files replaced the Poki bear pictures on 2026-11-14. The Poki bear was Poki's own character and
main brand asset, not covered by the AGPL-3.0-only license that applies to Poki's code; the Qeno panda
images in this folder are original Qeno artwork, so that restriction does not apply to them. The original
bear files are kept outside the repo as a backup.

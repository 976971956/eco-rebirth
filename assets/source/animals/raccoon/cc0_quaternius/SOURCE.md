# Raccoon source audit

The checked-in `Raccoon.blend` is the unmodified CC0 file from Quaternius'
official Cube World Kit. Embedded scripts are never executed; source audits use
Blender's `--disable-autoexec` option.

Source audit:

- one 1,488-vertex / 2,876-triangle mesh with a single atlas material;
- nine bones and nine weighted groups;
- eight animation actions;
- clear mask and ring-tail markings, but intentionally cubic anatomy and
  one-segment limbs that do not meet the current near-realistic standard.

The production builder keeps the source as a traceable proportion, marking and
motion reference. `tools/blender/build_cinematic_raccoon.py` authors a new
continuous adult-raccoon surface with an arched back, short articulated limbs,
plantigrade grasping paws, fitted facial mask, continuous ring tail, 22 runtime
bones, two skill sockets and eight gameplay actions. Rebuild with
`tools/build_realistic_vertical_slice.sh`.

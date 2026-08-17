# Crested porcupine source audit

The checked-in `Porcupine.gltf`, `Porcupine.bin` and
`Porcupine_BaseColor.png` are the archived Google Poly asset “Porcupine” by
Poly by Google (asset id `17NdW1sy5PC`). The archive metadata records the asset
as public and `CREATIVE_COMMONS_BY`; attribution and change notes are preserved
in `LICENSE.txt`.

Source audit at import time:

- one unrigged mesh, 5,184 imported vertices / 1,728 triangles;
- one 2,048×2,048 base-color texture;
- no armature and no animation actions;
- a strong crested-porcupine outline and useful quill-flow reference, but
  blocky disconnected legs and rigid geometry that do not meet the project's
  articulated near-realistic standard.

Source SHA-256:

- `Porcupine.gltf`: `bb1753540ed3911124428f0409aed968a1ea482b2eb88a4cef67825fbbda7def`
- `Porcupine.bin`: `43918a831b23d766d7f52c9c21c055b61d0572633d09864dce63c0b279fab13a`
- `Porcupine_BaseColor.png`: `fce8af2a251f508f7dd5104ca975c5b145fb92d8c98277711182788fd04124ec`

The production builder uses the source only as traceable anatomy and quill
direction reference. `tools/blender/build_cinematic_porcupine.py` creates a new
continuous adult crested-porcupine body, short articulated plantigrade legs,
layered black-and-cream quills, 22 runtime bones, two skill sockets and eight
gameplay actions. Rebuild with `tools/build_realistic_vertical_slice.sh`.

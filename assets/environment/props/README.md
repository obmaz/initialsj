# Trackside nature models (Fuji Lakeside)

Low-poly pines, oaks, willows, bushes and rocks from the **Ultimate Nature Pack by Quaternius**
(<https://quaternius.com/packs/ultimatenature.html>), a free pack released under
**CC0 1.0 Universal** (public domain; commercial use and modification allowed, no attribution
required). The original licence text is kept in `QUATERNIUS-LICENSE.txt`. Credit is given here anyway.

Files are the pack's unmodified OBJ/MTL exports (14 of its 150 models). The game changes them only at
run time (`scripts/quaternius_props.gd`): materials are baked into vertex colours, models are scaled to
the track's proportions and merged into one surface so they share the batched props material.

Add only models with a clean CC0 (or equivalent public-domain) licence. Anything that requires
attribution, forbids commercial use or forbids modification must not be used; if a model's terms are
unclear, leave it out. Record every source and licence in this file.

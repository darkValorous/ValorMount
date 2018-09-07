ValorMount
---

ValorMount is intended to be a fairly simple mount manager based largely on my own preferences. I figured the addon had come far enough along that I would pretty up the UI a little, add some configuration options and release it on CurseForge. Who knows, maybe there are others who like my approach to mounting up :)

#### Features:
- Can be called with a key binding or a macro.
- Easy to set favorites - it just uses the Mount Journal.
- Option to save different favorites per character in the Mount Journal.
- By default it will avoid using Flying Mounts when you can't fly.
- Each flying favorite can be toggled to be used for both air and ground, or even ground only.
- Ability to override how the addon determines if the current area allows flying or not.
- If you have it, the Vashj'ir Seahorse is always summoned when swimming in Vashj'ir.
- Characters without riding skill yet will summon their faction's chauffeur should they have one.
- Favorited Aquatic Mounts are prioritized above all when swimming and flying is not available.
- Favorited Water Striders are prioritized above ground mounts while swimming but deprioritized on land.

#### Race/Class Specific Features:
- Monks have the option of Zen Flight if used while moving or falling.
- Shamans have the option of Ghost Wolf if used while moving or in combat.
- Druids will shapeshift to Travel Form when used in situations you cannot normally mount, such as moving, falling or in combat.
- Druids can toggle to ONLY use Flight Form for flying, or to include Flight Form as part of its random selection.
- Balance Druids can enable automatically returning to Moonkin form when shifting from Travel Form.
- Worgens can add Running Wild into the random selection for ground mounts.
- If my addon ValorWorgen is loaded, Worgens have the option of returning to Human Form when mounting.

Options can be set under Interface -> Addons -> ValorMount, or by typing /vm or /valormount \
The Key Binding can be set under Key Bindings -> Addons -> ValorMount \
If a macro is preferred, simply use this command: /click ValorMountButton
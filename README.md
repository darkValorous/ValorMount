ValorMount
---

ValorMount is intended to be a fairly simple mount manager based largely on my own preferences, with a few features that make for a better alternative than the default "Summon Random Favorite Mount".

#### Features:
- Can be called with a key binding or a macro.
- Easy to set favorites - it just uses the Mount Journal.
- Option to save different favorites per character in the Mount Journal.
- Priority system determines the type of mount to use, for example it will deprioritize Flying Mounts below Ground Mounts when you cannot fly.
- Each flying favorite can be toggled to be prioritized for both air and ground, or even ground only.
- Ability to override how the addon determines if the current area allows flying or not.
- If you have it, the Vashj'ir Seahorse is always summoned when swimming in Vashj'ir.
- Characters without riding skill yet will summon their faction's chauffeur should they have one.

#### Race/Class Specific Features:
- Monks have the option of Zen Flight if used while moving or falling.
- Shamans have the option of Ghost Wolf if used while moving or in combat.
- Druids will shapeshift to Travel Form when used in situations you cannot normally mount, such as moving, falling or in combat.
- Druids can toggle to always use Flight Form for flying, or to include Flight Form as part of its random selection.
- Balance Druids can enable automatically returning to Moonkin form when shifting from Travel Form.
- Worgens can add Running Wild into the random selection for ground mounts.
- If my addon ValorWorgen is loaded, Worgens have the option of returning to Human Form when mounting.

#### Underwater & Surface Detection:
- If Enabled (per Character), this attempts to determine if you are actually underwater or floating at the surface. This is only useful if you have Aquatic mounts as Favorites.
- When Enabled and Underwater, Favorited Aquatic Mounts are prioritized above all other mounts.
- When Disabled, Favorited Aquatic Mounts are only prioritized above ground mounts, flying remains the highest priority.
- Jumping at the surface in Vashj'ir will trigger summoning for the water surface instead.
- Note: Underwater breathing (except Vashj'ir) will break this detection and consider you to always be at the surface!
- Note for Undead players: Due to the racial, this feature will instead always consider you to be underwater - however when you jump at the surface and mount immediately, it assumes you are at the surface.

Options can be set under Interface -> Addons -> ValorMount, or by typing /vm or /valormount \
The Key Binding can be set under Key Bindings -> Addons -> ValorMount \
If a macro is preferred, simply use this command: /click ValorMountButton
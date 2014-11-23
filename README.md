ActionButtonUtils
=================
This is a WoW addon for client version 1.12 developed and tested on Feenix realms. It provides functions to add a retail-like glowing effect to action bars which can be used by other addons. If you are not a developer this addon by itself is probably useless to you.

Currently supported action bars:
<ul>
  <li>Blizzard Default UI</li>
  <li>Bartender2</li>
</ul>

Thanks to Lulleh @ Feenix for coming up with the idea of a backport for Vanilla.

All credits to Blizzard for the textures added to retail with the release of 4.0.6.

How to use?
===========

If you want to include the glowing by yourself, you can use the functions 
```lua
  ABG_AddOverlay(button)
  ABG_RemoveOverlay(button)
```
The highlighting is implemented via an additional frame with the button set as its parent, thus inheriting all rendering-related properties. Upon removal those frames will be stored in a list ready to be reused in the future to avoid unneccessary memory hogging.

The addon maintains an index of abilities and their corresponding action buttons. You have to configure the index to keep track of the ability you're interested in, by registering the texture of the ability accompanied by handler functions for adding and removing the desired ability to the action bars. These handler functions have to accept a single ActionButton as they will be called with any button assigned to a certain texture if that button gets added to or removed from the index. The functions providing access to this index are:

```lua
  ABI_Register(texture, handler, handler);
  ABI_Unregister(texture, handler, handler);
  
  ABI_Trigger(texture, handler);
```

For example if you wish to permanently highlight Overpower, you could simply do the following:
```lua
  ABI_Register("Interface\\Icons\\Ability_MeleeDamage", ABG_AddOverlay, ABG_RemoveOverlay);
```
The index updates on changing action buttons (e.g. dragging spells from the spell book), changing the action button page (e.g. via up/down) and on changing stances (i.e. warrior, druid). 
To remove hide the glowing created by the registration above, you could trigger a call like so:
```lua
  ABI_Trigger("Interface\\Icons\\Ability_MeleeDamage", ABG_RemoveOverlay);
```
This leaves the registered handlers in place and if you perform stance dances on a warrior, you will notice that only those buttons with Overpower will start glowing again, that are affected by the stance dance. To ultimately remove the permanent highlighting of Overpower, you'd have to unregister:
```lua
  ABI_Unregister("Interface\\Icons\\Ability_MeleeDamage", ABG_AddOverlay, ABG_RemoveOverlay);
```

Important Notes
===============
<ul>
  <li> While it is possible to pass ABG_AddOverlay and ABG_RemoveOverlay as handlers to ABI_Register, you should refrain from doing so as during the unregistration, the handlers will be removed "by value", hence multiple registrations of the same functions may impact each other. If you use this feature in a custom addon, you should include a prefix in you handler names that will (most likely) avoid any collision with other addons.
</ul>

Changelog
=========
<ul>
  <li>1.0.1</li>
  <ul>
    <li>fixed a bug where registering a new ability would discard the index for all other abilities</li>
    <li>registering a new spell will now cause the index to be fully recreated</li>
  </ul>
</ul>

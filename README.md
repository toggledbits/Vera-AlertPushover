# AlertPushover: Send Vera System Alerts to Pushover

## Introduction ##

Since Ezlo is going to a paid subscription model for their cloud service, I cobbled together this plugin for users that only need to receive alerts from their Vera hub without paying for a subscription or any other services their cloud offers.

Also, if you are looking at ensuring you are removed from dependency on Ezlo's cloud service, check out my [Vera-Decouple project on Github](https://github.com/toggledbits/Vera-Decouple).

If you are migrating away from Vera and have decided that an Ezlo hub doesn't meet your needs, check out my [Multi-System Reactor](https://reactor.toggledbits.com) project... it works with Home Assistant, Hubitat, ZWave-JS, MQTT, ...

## Reporting Bugs/Enhancement Requests ##

Bug reports and enhancement requests are welcome! Please use the "Issues" link for the [Github repository](https://github.com/toggledbits/Vera-AlertPushover) to open a new bug report, ask a question, or make an enhancement request.

If you're reporting an issue, you will be asked to provide log messages, so capture your Vera log (http://hub-local-ip/cgi-bin/cmh/log.sh?Device=LuaUPnP) and be prepared to extract AlertPushover messages from it if asked (or better yet, extract and post them first thing).

**Please do not use the Ezlo Community Forums for communication about this plugin (or any others of mine). I don't read the forums there any more but perhaps once per month or two, and I won't respond in any case.**

## Installation ##

**IMPORTANT:** This plugin is not distributed/updated in the Vera App Marketplace, which as of this writing has been down for months and is apparently not well supported within Ezlo these days. Updates will be offered exclusively through the plugin's [Github repository](https://github.com/toggledbits/Vera-AlertPushover).

1. Download the latest release package in ZIP format: [release packages](https://github.com/toggledbits/Vera-AlertPushover/releases)
2. Unzip the downloaded archive to a folder on your local system (remember where!).
3. Open the Vera UI in your browser.
4. Go to *Apps > Develop apps > Luup files*
5. Go the folder containing the unzipped files; select all of the files as a group, and drag them as a group to the *Upload* button in the Vera UI.
6. Wait for the upload to complete and your Vera to reload Luup.
7. [Hard refresh](https://www.howtogeek.com/672607/how-to-hard-refresh-your-web-browser-to-bypass-your-cache/) your browser.

**If and only if** you are installing this plugin for the first time, perform the following additional steps to create the AlertPushover master device:

1. Go to *Apps > Develop apps > Create device* in the Vera UI.
2. For *Description*, copy-paste: `AlertPushover`
2. For *Upnp Device Filename*, copy-paste: `D_AlertPushover.xml`
4. For *Upnp Implementation Filename*, copy-paste: `I_AlertPushover.xml`
5. Select a room if you wish.
6. Press *Create device*.
7. Go to *Apps > Develop apps > Test Luup code (Lua)*
8. Enter and run `luup.reload()`
9. Wait until Luup reloads and then hard-refresh your browser again (see last step above).

## Configuration ##

AlertPushover is configured by changing variables on the device in the Vera UI. Go to the Alert Pushover device, *Advanced* tab, and then click the *Variables* tab.

You will need to register for an account with Pushover at [https://pushover.net](https://pushover.net). You must register for an account on their web site or through one of their mobile apps. This will give you a user key (shown on the landing page when you log in), and then you can register an application to get an API token. Put the user key and token into the `PushoverUser` and `PushoverToken` variables, respectively, of the AlertPushover device.

If you run multiple Vera hubs, you may want to modify the `PushoverTitle` variable to help you discern which hub is sending the alerts you receive.

`PushoverPriority` and `SeverityMap` help determine the Pushover priority of messages. `PushoverPriority` sets the default priority for all alerts that don't match a mapping in `SeverityMap`. The map is a string of the form `s=p,s=p,...`, where `s` is the Vera alert severity and `p` is the Pushover message priority to use for that alert. If "X" is given for the Pushover priority (i.e. on the right side of the equal sign), the alert will not be sent to Pushover (it is still removed from Vera's alert queue). [Pushover priorities](https://pushover.net/api#priority) are -2 (lowest) to 2 (emergency); 0 is normal/default. Vera priorities are not documented, so you're going to have to discover these for yourself and map them as you find them. The Vera priority is included in the text of the Pushover message in square brackets before the message body.

`PushoverDevice` and `DeviceMap` work similarly to the priority scheme above. `PushoverDevice` is the default default (left blank, typically, to use whatever is the Pushover account default). Messages for specific Vera users can be re-routed to different devices using the map in `DeviceMap`, which is a comma separate list of `verausernumber=pushoverdevice` pairs. You will need to know the Vera user number of your user(s) to map alerts this way, but those can be found in the messages send to Pushover.

## License ##

AlertPushover is offered under the MIT License.

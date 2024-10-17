# Reboot All Horizon Desktops

Author: Cameron Fore, Omnissa
Last Edit: Jul 16, 2019
Version 1.0  

## Overview
<!-- Summary Start -->
With VMware vRealize Operations monitor the key metrics related to protocol performance and can alert when those metrics have reached critical thresholds.
<!-- Summary End -->
As the number of user sites or locations increases, having good visibility into the overall quality of connectivity of those sites to your Horizon View data center(s) becomes increasingly important. Having worked with many customers on troubleshooting connectivity between such locations, it has become clear that monitoring only at the physical network layer is not sufficient to properly diagnose user connectivity issues impacting the display protocol. In fact, in most cases, it's the configuration of the physical layer that causes the issue(s), and the device(s) in question do not have the ability to diagnose or detect their impact to the display protocol.

Alas, all hope is not lost! With vROPs for Horizon, we have the ability to monitor the key metrics related to protocol performance and can alert when those metrics have reached critical thresholds. We can also leverage a handy custom grouping feature to organize the remotely connected sessions into defined sites or locations, based on information available in the user's session data. We can then leverage Super Metrics to calculate the overall health of the group of connected sessions from that site, and then display and alert when the health has dropped below our SLA thresholds.

Sound like something you want to take on? Then read on!

http://cameronfore.com/2019/07/09/location-analysis-using-vrops-for-horizon/

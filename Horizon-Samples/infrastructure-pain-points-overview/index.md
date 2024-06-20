---
layout: page
title: Infrastructure Pain Points Overview - Samples
hide:
  #- navigation
  - toc
---

## Overview

The main reason for this vROPS dashboard is to get a high level overview about the pain points for the whole infrastructure regarding performance and availability. Based on Custom Groups with defined thresholds (as filters) you can see how well your infrastructure is running.

## Installation

- Dashboards
- Views
- Supermetrics

Import the Infrastructure Pain Points Dashboard into vROPS:
[Infrastructure Pain Points Daashboard](./InfrastructurePainPoints-Dashboard.json){ .md-button .md-button--primary }

Import the Infrastructure Pain Points View to support the Dashboard:
[Custom Host List, Cluster List and Datastore List Views](./HostList_ClusterList_DatastoreList-Views.xml){ .md-button .md-button--primary }

Import the following Group-Types and Custom Groups which are needed to support the view:
[Cluster Status](./Cluster_Status-CG.json){ .md-button .md-button--primary }
[Host Status](./Host_Status-CG.json){ .md-button .md-button--primary }
[Storage Status](./Storage_Status-CG.json){ .md-button .md-button--primary }

Import the Supermetrics which are needed to support the Custom Groups:
[Supermetrics](./supermetric.json){ .md-button .md-button--primary }

!!! Note
    Please don't forget to activate these Supermetrics in your Policy for the specific Group-types (Storage_Status, Host_Status, Cluster_Status). 
    **NOT for all Object Types**

Contributed by: Kevin Bruesch

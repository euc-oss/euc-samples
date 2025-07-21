---
layout: default
title: EUC Samples
hide:
  #- navigation
  - toc
---

# Code Samples

Welcome to the Omnissa [euc-samples](https://github.com/euc-oss/euc-samples) repository.  This project is intended for the community and Omnissa to share commonly used code snippets, sample apps, scripts and sensors that can aid Workspace ONE and Horizon administrators. 

Some examples of items found in this repository are:

* Custom XML Profile Payloads
* Script content for Custom Attributes
* Scripts to be leveraged via WS1 Scripts (Bash/shell, Python, Powershell, Batch, etc)
* Scripts to assist with automation against the various REST API's
* Sample Apps
* Workspace ONE Intelligence Dashboards
* Application deployment scripts and how-to guides
* Markdown Documents describing suggested best practices or procedures that may be outside the realm of typical documentation

Each product has an index page that provides the name, summary and link to the provided samples. The UEM-Samples index also includes Sensor and Scripts within the [UEM-Samples/Scripts](https://github.com/euc-oss/euc-samples/tree/main/UEM-Samples/Scripts) and [UEM-Samples/Sensors](https://github.com/euc-oss/euc-samples/tree/main/UEM-Samples/Sensors) folders respectively.

## Contributing to Samples

Each index page is dynamically generated reading the README.md for each application, utility or project and taking a summary built into a table and linking back to the summary. Each sample, therefore requires its own folder and README.md file. The README.md file also needs to include a `<!-- Summary Start -->` and `<!-- Summary End -->` tag that surrounds desired the description or summary.

The UEM-Samples index also includes Sensors and Scripts within the [UEM-Samples/Sensors](https://github.com/euc-oss/euc-samples/tree/main/UEM-Samples/Sensors) and [UEM-Samples/Scripts](https://github.com/euc-oss/euc-samples/tree/main/UEM-Samples/Scripts) folders respectively, reading the `# Description:` field from each sensor and script.

It is therefore important that when contributing samples, that the appropriate tags or fields are provided, otherwise the sample will not be included in the index.

## Sample Indexes 

* [Omnissa Access Samples](./Access-Samples/index.md)
* [App Volumes Samples](./App-Volumes-Samples/index.md)
* [DEEM Samples](./DEEM-Samples/index.md)
* [Horizon Samples](./Horizon-Samples/index.md)
* [Omnissa Intelligence Samples](./Intelligence-Samples/index.md)
* [Unified Access Gateway Samples](./UAG-Samples/index.md)
* [Workspace ONE UEM Samples](./UEM-Samples/index.md)
* [Workspace ONE UEM Scripts Samples](./UEM-Samples/scripts-index.md)
* [Workspace ONE UEM Sensors Samples](./UEM-Samples/sensors-index.md)

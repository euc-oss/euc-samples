# euc-samples

## Introduction

Welcome to th Omnissa **euc-samples** repository.  This project is intended for the community and Omnissa to share commonly used code snippets, sample apps, scripts and sensors that can aid Workspace ONE and Horizon administrators. 

Some examples of items to submit for consideration and use by the community:

* Custom XML Profile Payloads
* Script content for Custom Attributes
* Scripts to be leveraged via WS1 Scripts (Bash/shell, Python, Powershell, Batch, etc)
* Scripts to assist with automation against the various REST API's
* Markdown Documents describing suggested best practices or procedures that may be outside the realm of typical documentation

## Downloads

By downloading, installing, or using the Software, you agree to be bound by the terms of the License Agreement unless there is a different license provided in or specifically referenced by the downloaded file or package. If you disagree with any terms of the agreement, then do not use the Software.

## developer.omnissa.com

This repo is structured to feed into the developer.omnissa.com Developer Portal via the [](https://github.com/euc-dev/euc-dev.github.io) repo using MkDocs published by GitHub Pages. An index of all scripts, snippets, tools, sensors etc is automatically created and stored within the `/docs` folder. Do not modify this folder. 

This folder will be integrated into the [developer portal repo](https://developer.omnissa.com).

## Submitting samples

The euc-samples project team welcomes contributions from the community.

### Required Information

The following information must be included in a README.md for the submission. If the submission is a WS1 UEM Sensor or Script, then see the [Sensor README.md](./UEM-Samples/Sensors/README.md) and [Scripts README.md](./UEM-Samples/Scripts/README.md) for required information.

* Author Name
  
  This can include full name, email address or other identifiable piece of information that would allow interested parties to contact author with questions.
* Date
  
  Date the sample was originally written
* Minimal/High Level Description

  What does the sample do?
* Any KNOWN limitations or dependencies

### Suggested Information

The following information should be included when possible. Inclusion of information provides valuable information to consumers of the resource.

* Product version against which the sample was developed/tested
* Client Operating System version against which the sample was developed/tested (e.g. Windows Build number, or macOS Version and Build Number)
* Language (Bash/Python/Powershell) version against which the sample was developed/tested

### Contribution Process

Please see the [CONTRIBUTING.md](https://github.com/euc-oss/.github/blob/main/CONTRIBUTING.md).

### Developer Certificate of Origin

Before you start working with euc-samples, please read our [Developer Certificate of Origin](https://github.com/euc-dev/.github/blob/main/Developer%20Certificate%20of%20Origin.md) document. All contributions to this repository must be signed as described on that page. Your signature certifies that you wrote the patch or have the right to pass it on as an open-source patch.

### Code Style

We won't actively enforce any "official" style guides, but do ask that you do what you can to:
* Make your samples easily readable
* Make your samples easily reusable
* Include in-line comments to help with readability

## Resource Maintenance

### Maintenance Ownership

Maintenance of any and all submitted samples is to be performed by the community.  If you can make a sample better, please feel free to submit a pull request to improve it!

### Filing Issues

Any bugs or other issues should be filed within GitHub by way of the repository’s Issue Tracker.

### Resolving Issues

Any community member can resolve issues within the repository, however only the Project Team can approve the update. Once approved, assuming the resolution involves a pull request, only a Project Team member will be able to merge and close the request.

### Windows Users

Some of the samples result in a long file path that may cause cloning to fail on Windows machines. If you an error message is displayed during cloning indicating that the file name is too long then run the below command to allow longer file names during checkout.
* ```git config --system core.longpaths true```
* [Additional Information](https://confluence.atlassian.com/bamkb/git-checkouts-fail-on-windows-with-filename-too-long-error-unable-to-create-file-errors-867363792.html)

## License

This project is licensed under the Creative Commons Attribution 4.0 International as described in [LICENSE](https://github.com/euc-dev/.github/blob/main/LICENSE); you may not use this file except in compliance with the License.

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

## Omnissa Resources

* [Omnissa Developer Portal](https://developer.omnissa.com)
* [Tech Zone](https://techzone.omnissa.com)
* [Omnissa Community](https://community.omnissa.com)
* [Omnissa Company Wedsite](https://omnissa.com)

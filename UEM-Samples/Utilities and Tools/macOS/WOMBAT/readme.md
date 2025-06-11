# WOMBAT - Workspace ONE macOS Baselines Authoring Tool

## Overview

WOMBAT (Workspace ONE macOS Baselines Authoring Tool) is a macOS application designed to help organizations deploy security configuration standards for Apple devices within their Workspace ONE UEM environment. The tool integrates with established security frameworks and transforms them into deployable baseline configurations.

⚠️ **Important Notice**: This tool is not an Omnissa, macOS Security Compliance Project (mSCP), Secure Controls Framework (SCF), or Apple product or offering and is not supported by any of these organizations or projects.

## Key Features

### 🔒 Security Standards Integration
- Integrates with the macOS Security Compliance Project (mSCP) and Secure Controls Framework (SCF)
- Supports federal standards (NIST 800-53, NIST 800-171, CNSSI 1253)
- Includes industry benchmarks (CIS Benchmarks)
- Provides implementation guides (STIGs)
- Supports compliance frameworks (CMMC, PCI DSS, HIPAA, ISO 27001)

### ✅ Custom Baseline Creation
- Review, edit, and update existing security configuration standards
- Choose between audit-only or remediate-and-audit approaches
- Add additional rules not included in baseline configurations
- Support for multiple macOS versions and security frameworks
- Organizational value customization for specific requirements

### 📄 Profile and Script Generation
- Automatically generates Workspace ONE UEM custom settings profiles
- Creates remediation scripts for applying security configurations
- Generates audit scripts and sensors for compliance monitoring
- Consolidates multiple configurations into single deployable packages

### ☁️ Workspace ONE UEM Integration
- Direct upload to Workspace ONE UEM environments
- Support for both Basic Authentication and OAuth 2.0
- Organization Group management and selection
- Smart Groups deployment recommendations

## System Requirements

- **Operating System**: macOS 12.0 (Monterey) or later
- **Xcode**: 15.0 or later (for development)
- **Swift**: 5.9 or later
- **Workspace ONE UEM**: Compatible with current UEM versions
- **Network Access**: Internet connection required for GitHub integration

## Getting Started

### 1. Accept Disclaimer
Review and acknowledge the risks associated with security baseline deployment. We strongly recommend testing configurations on non-production devices first.

### 2. Configure Settings
1. Navigate to **Settings** in the application
2. Enter your Workspace ONE UEM details:
   - **Server URL**: Your UEM console URL (e.g., `https://as###.awmdm.com`)
   - **Authentication Method**: Choose between Basic Authentication or OAuth 2.0
   - **Credentials**: Enter appropriate authentication details
3. Select your **Organization Group**
4. (Optional) Add a **GitHub Token** to avoid API rate limits

### 3. Create Security Baseline
1. Click on **Security Baselines**
2. Select your target platform and OS version
3. Choose an industry baseline (CIS, NIST, STIG, etc.)
4. Review and configure each section:
   - **Configure Rules**: Review each rule and decide whether to include it
   - **Set Organizational Values**: Customize settings for your environment
   - **Choose Remediation**: Select audit-only or remediate-and-audit
5. Add additional rules if required at the "Add Rule" stage

### 4. Review and Upload
1. Review your baseline's risk profile and selected rules
2. Choose consolidated compliance checking for efficient monitoring
3. Upload to create:
   - Single configuration profile containing all settings
   - Remediation script that applies all required changes
   - Audit script that validates compliance
   - Two sensors that report audit results

## Authentication Methods

### OAuth 2.0 (Recommended)
1. Go to UEM Console > Groups & Settings > Configurations
2. Search for "OAuth Client Management"
3. Create a new OAuth client with appropriate scopes
4. Use the Region Helper to select the correct Token URL:
   - **AMER (SaaS)**: `https://na.uemauth.workspaceone.com/connect/token`
   - **EMEA (SaaS)**: `https://emea.uemauth.workspaceone.com/connect/token`
   - **APAC (SaaS)**: `https://apac.uemauth.workspaceone.com/connect/token`
   - **UAT (SaaS)**: `https://uat.uemauth.workspaceone.com/connect/token`

### Basic Authentication (Legacy)
⚠️ Basic authentication is being deprecated. Consider migrating to OAuth 2.0 for better security and future compatibility.

## Data Sources

### macOS Security Compliance Project (mSCP)
- **Repository**: [github.com/usnistgov/macos_security](https://github.com/usnistgov/macos_security)
- **Description**: Open-source security guidance for macOS including baselines, benchmarks, and configuration guides from NIST, CIS, DISA, and other organizations

### Secure Controls Framework (SCF)
- **Repository**: [github.com/securecontrolsframework/securecontrolsframework](https://github.com/securecontrolsframework/securecontrolsframework)
- **Description**: Comprehensive cybersecurity and privacy control framework with over 1,000 requirements from more than 100 laws, regulations, and standards

## Deployment Workflow

### Generated Assets
WOMBAT creates the following assets when uploading a baseline:
- **Configuration Profile**: Single UEM profile containing all baseline settings
- **Remediation Script**: Applies all required security changes
- **Audit Script**: Validates compliance against baseline requirements
- **Compliance Sensors**: Monitor and report audit results

### UEM Implementation Steps
1. **Apply Baseline Profile**: Locate the profile in UEM Console and assign it to a Smart Group. Begin with a single test device before broader deployment.

2. **Manage Profile Conflicts**: Your baseline profile contains multiple payloads that may conflict with existing profiles. Review and resolve conflicts manually.

3. **Deploy Remediation Script**: Find and assign the remediation script to the same Smart Group. Configure an appropriate execution schedule.

4. **Configure Audit Script**: Assign the audit script to the same Smart Group, ensuring it runs after the remediation script. Set it to run periodically.

5. **Monitor Audit Results**: Audit results are saved to `/tmp/AuditResults.txt` with overall status in `/tmp/BaselineCheck.txt`. Compliance is determined by all audit checks matching expected results.

6. **Implement Compliance Sensor**: Assign the sensors to the same Smart Group. The compliance sensor returns 'true' or 'false' based on device compliance. The compliance level sensor returns a percentage value.

7. **Customize as Needed**: Feel free to modify scripts and sensors to fit your requirements. Note that WOMBAT does not provide functionality to revert applied remediations.

### Compliance Monitoring
- **Audit Results**: Detailed results saved to `/tmp/AuditResults.txt`
- **Overall Status**: Summary stored in `/tmp/BaselineCheck.txt`
- **Compliance Sensor**: Returns boolean compliance status
- **Compliance Level Sensor**: Returns percentage compliance value

## Supported Security Standards

### Federal Standards
- **NIST 800-53**: Controls at Low, Moderate, and High impact levels
- **NIST 800-171**: Controlled Unclassified Information protection
- **CNSSI 1253**: National security system categorization

### Industry Benchmarks
- **CIS Benchmarks**: Configuration guidelines with Level 1 and Level 2 implementations

### Implementation Guides
- **STIGs**: Detailed technical guidance for securing Apple systems

### Certification Models
- **CMMC**: Security process maturity levels for defense contractors

### Compliance Frameworks
- Standards from SCF mapping to specific regulatory requirements including PCI DSS, HIPAA, ISO 27001, and many others

## Current Limitations

### Declarative Device Management (DDM)
DDM profiles are not currently supported. Rules are listed for reference but cannot be uploaded to Workspace ONE UEM yet.

### mSCP Supplemental Policies
Supplemental policies without remediation or audit capabilities are excluded from baseline generation. Please check the [supplemental rules documentation](https://github.com/usnistgov/macos_security/tree/main/rules/supplemental) for more information.

### No-Action Rules
Rules without actionable fixes or audit checks are filtered out to ensure baseline functionality.

### Profile Settings and Scripts
Profile settings, scripts, and audit checks are provided as-is from the macOS Security Compliance Project. Remediation scripts and audit checks are consolidated into scripts that can be reviewed and edited in Workspace ONE UEM.

## How It Works

This app connects to the mSCP GitHub repository to download security standards, which are then transformed into deployable configurations for Workspace ONE UEM. It also incorporates SCF data to provide broader compliance mappings for organizations with specific regulatory requirements.

To ensure the best experience, baseline configurations are limited to rules that include profiles, scripts, or audit functionality.

## Contributing

This project integrates with several open-source initiatives:
- Contribute to mSCP: [github.com/usnistgov/macos_security](https://github.com/usnistgov/macos_security)
- Contribute to SCF: [github.com/securecontrolsframework/securecontrolsframework](https://github.com/securecontrolsframework/securecontrolsframework)

## Support and Resources

### Documentation
- [mSCP Documentation](https://github.com/usnistgov/macos_security)
- [SCF Documentation](https://github.com/securecontrolsframework/securecontrolsframework)
- [Workspace ONE UEM Documentation](https://docs.omnissa.com/)

### Community Resources
- [macOS Security Community](https://github.com/usnistgov/macos_security)

## License

This project is provided under appropriate licensing terms. Please review the license file for specific details and ensure compliance with all referenced project licenses.

## Disclaimer

This tool is not officially endorsed by Omnissa, Apple, NIST, or any referenced security organizations. It is provided as-is for organizations to use in their security baseline deployment workflows. Always test configurations in non-production environments before deployment.

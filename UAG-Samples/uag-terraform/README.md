# uag-terraform

Omnissa® has developed a custom tooling for lifecycle management of Unified Access Gateway with Terraform . Using this tooling, you can deploy UAGs or upgrade the existing instance. The provider is developed and maintained by Omnissa® . 

## Downloads

By downloading, installing, or using the Software, you agree to be bound by the terms of Omnissa’s Software Development Kit License Agreement unless there is a different license provided in or specifically referenced by the downloaded file or package. If you disagree with any terms of the agreement, then do not use the Software.

## License

This project is licensed under the Creative Commons Attribution 4.0 International as described in [LICENSE](https://github.com/euc-dev/.github/blob/main/LICENSE); you may not use this file except in compliance with the License.

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

## Steps

Steps to deploy UAG using terraform on different hypervisors:

1. Prepare the ini file for deployment

2. Prepare sensitive_inputs.ini with the credentials
[<uag_name> added in module]
rootPassword=<password>
adminPassword=<password>
awAPIServerPwd=<password>
awTunnelGatewayAPIServerPwd=<password>
awCGAPIServerPwd=<password>
awSEGAPIServerPwd=<password>

3. Add module in main.tf file for vsphere/aws/gce
`module "<module_name>" {
  source    = "./uag_vsphere_module" or "./uag_aws_module" or "./uag_gce_module"
  uag_name  = "<uag_name>"  
  uag_count = <num of UAGs to be deployed>
  iniFile   = "uag.ini"
  inputs    = var.sensitive_input
}`

4. Run terraform init

5. Run terraform apply -target=module.<module_name>
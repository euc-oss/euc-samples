package main

import (
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func resourceUAG() *schema.Resource {
	return &schema.Resource{
		Create: resourceUAGCreate,
		Read:   resourceUAGRead,
		Update: resourceUAGUpdate,
		Delete: resourceUAGDelete,
		Schema: map[string]*schema.Schema{
			"uag_name": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
			},
			"deployment_option": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
			},
			"os_login_username": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
			},
			"ssh_enabled": &schema.Schema{
				Type:     schema.TypeBool,
				Required: true,
			},
			"ssh_key_access_enabled": &schema.Schema{
				Type:     schema.TypeBool,
				Required: true,
			},
			"admin_password": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
			},
			"ip_mode0": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
			},
			"root_password": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
			},
			"horizon_settings": &schema.Schema{
				MaxItems: 1,
				Type:     schema.TypeList,
				Optional: true,
				Elem: &schema.Resource{
					Schema: map[string]*schema.Schema{
						"enabled": &schema.Schema{
							Type:     schema.TypeBool,
							Required: true,
						},
						"identifier": &schema.Schema{
							Type:     schema.TypeString,
							Required: true,
						},
					},
				},
			},
		},
	}
}

func resourceUAGCreate(d *schema.ResourceData, m interface{}) error {
	// perform input validations, certificate import
	// save state in Terraform, to be used to create meta-data for VM instance resource on cloud platform
	uag_name := d.Get("uag_name").(string)
	d.SetId(uag_name)
	return nil
}
func resourceUAGRead(d *schema.ResourceData, m interface{}) error {
	// access get APIs of UAG
	// record all changes made from admin UI on UAG
	return nil
}
func resourceUAGUpdate(d *schema.ResourceData, m interface{}) error {
	// access put/post APIs of UAG
	// custom functions for certUpdate, passwordRollover
	hz_settings := d.Get("horizon_settings").([]interface{})[0]
	_ = hz_settings.(map[string]interface{})
	return nil
}
func resourceUAGDelete(d *schema.ResourceData, m interface{}) error {
	return nil
}
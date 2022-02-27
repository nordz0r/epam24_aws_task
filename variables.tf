# Vars
## Region settings
variable "region" {
  type = string
  default = "eu-west-2"
  description = "Default Region"
}

## Access key
variable "access_key" {
  type = string
  description = "Enter your access_key"
}

## Secret key
variable "secret_key" {
  type = string
  description = "Enter your secret_key"
}

## Database credentials
variable rds_credentials {
  type    = object({
    username = string
    password = string
    dbname = string
  })

  default = {
    username = "db_admin"
    password = "db_password"
    dbname = "db_wordpress"
  }
  description = "RDS user, password and database"
}

## Instance type
variable "instance_type" {
  type = string
  default = "t2.micro"
  description = "Webservers and RDS instance_type"
}

## Tags
variable "tags" {
  type = map
  default = {
    Owner   = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
  description = "Default tags"
}
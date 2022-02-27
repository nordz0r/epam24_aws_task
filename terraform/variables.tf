# Vars

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


variable "instance_type" {
  default = "t2.micro"
}
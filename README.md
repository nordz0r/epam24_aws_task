# epam24_aws_task
AWS Task Epam Stream24:

![Task](task.png)


The task is implemented with terraform

Install:
* git clone https://github.com/nordz0r/epam24_aws_task
* cd epam24_aws_task
* terraform init
* terraform apply

Input data:
* Enter your access_key
* Enter your secret_key

Output data:
* Balancer-Wordpress URL
* Wordpress credentials
* Database credentials

Check:
* Go to the LoadBalancer home page
* F5 (refresh page)
* Site-title must show current ec2-instance hostname

# r53-resolver-multiple-account-demo
This is a Terraform demo showing how to use Route 53 Resolver and Route 53
Private Hosted Zones across multiple accounts.

![Architecture](./architecture.png)

## Quick setup

### Prerequisites
1. Install Python 3.6+, pip, Boto 3, the AWS CLI, and Terraform **0.12** (or later; 0.11 will not work) if you haven't already.
   * [Python 3](https://realpython.com/installing-python/)
   * [pip](https://pip.pypa.io/en/stable/installing/)
   * Boto 3: `pip install --user boto3`
   * AWS CLI: `pip install --user awscli`
       * You may need to adjust your PATH to include the pip `~/.local/bin`
         or equivalent to get the `aws` command.
   * [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html)
2. Create two AWS accounts (they do not need to be in the same organization).
   We will refer to them as the resolver account (holding the Route 53 Resolver
   Rules, Outbound Endpoints, Private Hosted Zone) and the target account
   (which accesses these resources).
3. Create IAM users in each of the accounts and save the access and secret keys
   as separate profiles in `~/.aws/credentials`. For example:
   ```
   [target]
   aws_access_key_id = AKIAIOSFODNN7EXAMPLE
   aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

   [resolver]
   aws_access_key_id = AKIAR6GLBEMU6EXAMPLE
   aws_secret_access_key = PknkCid6cvFuGTk/k2cjdcUEEJNjifEXAMPLEKEY
   ```
4. Upload your SSH public key to EC2 in both accounts with the same name, e.g.
   `mykey`.
5. Clone this repository:  
   <pre>% <b><font color="blue">git clone https://github.com/dacut/r53-resolver-multiple-account-demo.git</font></b></pre>

6. Go to the demos directory:  
   <pre>% <b><font color="blue">cd r53-resolver-multiple-account-demo/demos</font></b></pre>
7. Initialize Terraform:  
   <pre>
   % <b><font color="blue">terraform init</font></b>
   Initializing modules...
   - resolver in ../modules/resolver
   - target in ../modules/target

   Initializing the backend...

   Initializing provider plugins...
   \- Checking for available provider plugins...
   \- Downloading plugin for provider "aws" (terraform-providers/aws) 2.18.0...
   \- Downloading plugin for provider "null" (terraform-providers/null) 2.1.2...  
   Terraform has been successfully initialized!  
   You may now begin working with Terraform. Try running "terraform plan" to see
   any changes that are required for your infrastructure. All Terraform commands
   should now work.  
   If you ever set or change modules or backend configuration for Terraform,
   rerun this command to reinitialize your working directory. If you forget, other
   commands will detect it and remind you to do so if necessary.
   </pre>
8. Apply the template, answering a few questions to start:  
   <pre>
   % <b><font color="blue">terraform apply</font></b>
   var.keypair
     Enter a value: <b><font color="blue">mykey</font></b>  
   var.resolver_account_profile
     Enter a value: <b><font color="blue">resolver</font></b>  
   var.target_account_profile
     Enter a value: <b><font color="blue">target</font></b>  
   data.aws_caller_identity.target: Refreshing state...
   module.target.data.aws_availability_zones.available: Refreshing state...
   module.target.data.aws_ami.amzn2: Refreshing state...
   module.resolver.data.aws_availability_zones.available: Refreshing state...
   module.resolver.data.aws_ami.amzn2: Refreshing state...  
   An execution plan has been generated and is shown below.
   Resource actions are indicated with the following symbols:
     + create  
   Terraform will perform the following actions:
   ...
   Plan: 46 to add, 0 to change, 0 to destroy.  
   Do you want to perform these actions?
     Terraform will perform the actions described above.
     Only 'yes' will be accepted to approve.  
     Enter a value: <b><font color="blue">yes</font></b>
   ...
   Apply complete! Resources: 46 added, 0 changed, 0 destroyed.  
   Outputs:  
   dns_instance_ipv4 = <i>dns-ip-address</i>
   lookup_instance_ipv4 = <i>lookup-ip-address</i>
   resolver_rule_id = rslvr-rr-<i>id</i>
   resolver_vpc_id = vpc-<i>id</i>
   target_vpc_id = vpc-<i>id</i>
   zone_id = Z<i>ID</i>
   </pre>
9. Make a note of the outputs. If you need to retrieve them again, run `terraform output`.
10. Wait a minute for the DNS server to bootstrap itself.
11. Log in to the DNS lookup test host and perform test queries:
   <pre>
   % <b><font color="blue">ssh ec2-user@<i>test-host-ip-address</i></font></b>
   Warning: Permanently added '&lt;ip-address&gt;' (ECDSA) to the list of known hosts.
   
          __|  __|_  )
          _|  (     /   Amazon Linux 2 AMI
         ___|\___|___|
   
   https://aws.amazon.com/amazon-linux-2/
   % <b><font color="blue">dig +nostats +nocmd TXT example.com</font></b>
   ;; Got answer:
   ;; -&gt;&gt;HEADER&lt;&lt;- opcode: QUERY, status: NOERROR, id: 8165
   ;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0
   
   ;; QUESTION SECTION:
   ;example.com.                   IN       TXT
   
   ;; ANSWER SECTION:
   example.com.	           10      IN       TXT    "R53 Resolver Demo - Route 53 Private Hosted Zone"
   % <b><font color="blue">dig +nostats +nocmd TXT onprem.example.com</font></b>
   ;; Got answer:
   ;; -&gt;&gt;HEADER&lt;&lt;- opcode: QUERY, status: NOERROR, id: 23536
   ;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0
   
   ;; QUESTION SECTION:
   ;onprem.example.com.	           IN       TXT
   
   ;; ANSWER SECTION:
   onprem.example.com.     60      IN       TXT    "R53 Resolver Demo - On-premises zone"
   % <b><font color="blue">dig +nostats +nocmd TXT amazon.com</font></b>
   ;; Got answer:
   ;; -&gt;&gt;HEADER&lt;&lt;- opcode: QUERY, status: NOERROR, id: 8698
   ;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 0
   
   ;; QUESTION SECTION:
   ;amazon.com.                    IN       TXT
   
   ;; ANSWER SECTION:
   amazon.com.             60      IN       TXT    "spf2.0/pra ..."
   amazon.com.             60      IN       TXT    "v=spf1 ..."
   amazon.com.             60      IN       TXT    "..."
   </pre>

# Declaring the provider

provider "aws" {
  region = "ap-south-1"
  profile = "jaggu"
}

# Create Security group with HTTP and SSH

resource "aws_security_group" "security" {
  name        = "security"
  description = "Allow SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysecurity"
  }
}

# Creating key pair


resource "tls_private_key" "mykey" {
	algorithm = "RSA"  
	rsa_bits = 4096
}

resource "local_file" "keyfile" {
	filename = "C:/Users/Lenovo/Desktop/terra/mytest/key1.pem"
}

resource "aws_key_pair" "mykey" {
	key_name = "key1"
	public_key = tls_private_key.mykey.public_key_openssh
}



# Create EBS volume

resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.os1.availability_zone
  size              = 1
  tags = {
    Name = "myebs"
  }
}


# Creating Instance

resource "aws_instance" "os1" {
 depends_on = [
local_file.keyfile,
aws_key_pair.mykey,
tls_private_key.mykey,
]
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.mykey.key_name
  
  security_groups = [ "${aws_security_group.security.name}" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mykey.private_key_pem   
    host     = aws_instance.os1.public_ip
  }

  provisioner "remote-exec" {
    inline = [
       
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "os1"
  }
}

# Attaching the EBS Volume

resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.os1.id
  force_detach = true
depends_on = [
    aws_ebs_volume.ebs1,
    aws_instance.os1
  ]

}

# Format, mount and download git data in directory 

resource "null_resource" "nr"  {
depends_on = [
    aws_volume_attachment.ebs_attach,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mykey.private_key_pem 
    host     = aws_instance.os1.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/jagratibhatnagar/cc.git /var/www/html/"
    ]
  }
}



# Creating s3 Bucket

resource "aws_s3_bucket" "bucket1task" {
  bucket = "bucket1task"
  acl = "public-read"
provisioner "local-exec" {

     command = "mkdir gitpull | git clone https://github.com/jagratibhatnagar/image gitpull"
}

  tags = {
 Name = "bucket1task"
}
}


# Uploading image in s3 Bucket

resource "aws_s3_bucket_object" "image-pull" {
depends_on = [
    aws_s3_bucket.bucket1task,
]
  bucket = aws_s3_bucket.bucket1task.id 
  key    = "code-wallpapeer-8.jpg"
  acl = "public-read"
  source = "gitpull/code-wallpaper-8.jpg"

}

# Creating cloudFront Distribution

locals {
  s3_origin_id = "myoriginid"
      }
resource "aws_cloudfront_distribution" "s3-distribution" {
origin {
domain_name = aws_s3_bucket.bucket1task.bucket_regional_domain_name
origin_id =  local.s3_origin_id  
custom_origin_config {
        http_port = 80
        https_port = 80
        origin_protocol_policy = "match-viewer"
        origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
         }
      }

 enabled = true
 is_ipv6_enabled = true

 default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]

    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

     viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    }

   restrictions {
      geo_restriction {
          restriction_type = "none"
     }
   }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

   connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = file("C:/Users/Lenovo/Desktop/terra/mytest/key1.pem")
      host     = aws_instance.os1.public_ip
  
      }
}

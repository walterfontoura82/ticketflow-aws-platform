/*
AWS publica el ID de la AMI más reciente de Amazon Linux 2023 en Parameter
Store. Consultarlo evita hardcodear un AMI ID que cambia entre regiones.

Amazon Linux 2023 incluye SSM Agent, que permitirá administrar la instancia
sin SSH ni dirección IP pública.
*/
data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

/*
Política de confianza del rol.

Sólo el servicio EC2 puede asumir este rol. No concede todavía permisos
sobre AWS: únicamente define quién puede utilizar la identidad.
*/
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.project_name}-${var.environment}-admin-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-admin-ec2-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

/*
AmazonSSMManagedInstanceCore permite que SSM Agent se registre y mantenga
los canales necesarios para Session Manager.

No concede acceso administrativo general a otros recursos AWS.
*/
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

/*
EC2 recibe roles mediante un instance profile.
El profile actúa como contenedor del rol asociado a la instancia.
*/
resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}-${var.environment}-admin-ec2-profile"
  role = aws_iam_role.this.name
}

/*
Instancia administrativa privada.

Decisiones:
- Sin IP pública.
- Sin key pair ni SSH.
- IMDSv2 obligatorio para proteger las credenciales temporales.
- Volumen raíz gp3 cifrado.
- Acceso mediante Systems Manager.
*/
resource "aws_instance" "this" {
  ami           = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [
    var.security_group_id
  ]

  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.this.name
  lifecycle {
    # La AMI más reciente se usa al crear la instancia, pero una actualización
    # del parámetro SSM no debe reemplazar automáticamente la EC2 administrativa.
    ignore_changes = [ami]
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-admin"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Role        = "database-administration"
  }
}

# Descrição Técnica da Tarefa 1

## Introdução
Este código foi escrito em **Terraform**, uma ferramenta de código aberto para **Infraestrutura como Código (IaC)**. Neste arquivo, explicarei cada etapa do código para facilitar sua compreensão.

## Provider
O código inicia com o comando `provider "aws"`, que permite ao Terraform interagir com o provedor **AWS** (Amazon Web Services). Dentro da configuração, o parâmetro `region` define a região onde os recursos serão provisionados. No exemplo, a região é definida como `us-east-1`.

## Variáveis
As variáveis `projeto` e `candidato` permitem personalizar dinamicamente o nome dos recursos, facilitando a reutilização do código para diferentes implementações.

## Chave Privada
O recurso `tls_private_key` utiliza o provedor **tls** para criar uma chave privada RSA de 2048 bits. Este algoritmo é amplamente utilizado para autenticação e criptografia.

## Par de Chaves
O recurso `aws_key_pair` cria um par de chaves na **AWS**, associando a chave pública gerada à instância EC2. Isso permitirá autenticação via **SSH** (Secure Shell), um protocolo seguro de comunicação entre sistemas.

## VPC (Virtual Private Cloud)
O recurso **VPC** cria uma rede virtual na AWS. O parâmetro `cidr_block` define o intervalo de endereços IP da VPC. As opções `enable_dns_support` e `enable_dns_hostnames` fornecem suporte e resoluções DNS, essenciais para o funcionamento da VPC.

## Sub-rede
A **sub-rede** é um subconjunto de endereços IP dentro da VPC, utilizada para segmentar a rede.

## Gateway de Internet
O recurso `aws_internet_gateway` define um gateway de internet, permitindo que os recursos dentro da VPC se conectem à internet. O parâmetro `vpc_id` associa o gateway à VPC.

## Tabela de Roteamento e Associação
O recurso `aws_route_table` cria uma tabela de rotas, direcionando o tráfego dentro da VPC. A rota configurada aponta para o IP `0.0.0.0/0`, que direciona o tráfego para o gateway de internet. A tabela de rotas é associada à sub-rede através do recurso `aws_route_table_association`.

## Grupo de Segurança
O **grupo de segurança** define as regras de controle de tráfego de entrada e saída da instância. Ele é fundamental para garantir a segurança dos recursos provisionados.

## data.aws_ami
A configuração `data.aws_ami` pesquisa a **Amazon Machine Image (AMI)** mais recente do sistema operacional Debian 12, utilizando filtros que garantem compatibilidade com virtualização HVM.

## Instância EC2
O recurso `aws_instance` provisiona uma instância **EC2** baseada no sistema **Debian 12**. A instância é configurada com 20 GB de armazenamento em um volume **gp2** e utiliza o par de chaves para permitir acesso SSH.

### User Data
Um script de inicialização no bloco `user_data` automatiza tarefas, como a atualização e otimização do sistema operacional ao iniciar a instância.

## Tags
Várias `tags` foram utilizadas ao longo do código para adicionar metadados aos recursos, facilitando a identificação e organização dentro da AWS.


# Descrição Técnica da Tarefa 2

Após uma análise do arquivo `main.tf` em seu formato inicial, identifiquei algumas fragilidades e implementei melhorias significativas para aumentar a segurança do código.

## Segurança dos Grupos de Segurança
A primeira alteração foi aprimorar as regras de segurança do **Security Group**. Anteriormente, a instância poderia ser acessada por qualquer IP. Agora, a regra foi alterada para permitir acesso apenas ao usuário com o endereço IP **[26.64.12.12/32]**. Essa modificação reduz significativamente o risco de ataques externos.

## Chaves SSH Geradas com TLS
O código original não incluía chaves de acesso seguras geradas via Terraform. Para resolver isso, adicionei chaves privadas utilizando o recurso **tls**. Isso garante que a chave privada utilizada para acessar a instância seja gerada diretamente no ambiente do Terraform, aumentando a segurança. Além disso, marquei a chave como **sensitive** nos outputs (`sensitive = true`), o que evita que ela seja exibida abertamente durante a execução do Terraform, protegendo-a de exposição inadequada nos logs.

## Controle de IP Público
Explicitamos a associação de um endereço IP público com a instância (`associate_public_ip_address = true`), garantindo que o acesso externo controlado via SSH seja possível. Essa mudança facilita a administração, permitindo identificar facilmente onde o servidor está exposto e monitorar sua segurança.

## Restrição de Portas
No código original, todas as portas estavam abertas para entrada de tráfego, o que representava um grande risco de segurança. Restrinjo a entrada apenas à porta **22** para SSH, eliminando qualquer possibilidade de acesso indevido.

## Recursos de Rede
Antes, os recursos de rede, como gateways, não tinham regras de controle e roteamento. Implementei regras para controlar o tráfego de saída, garantindo que ele passe por um **Internet Gateway** com rotas explicitamente definidas. Também adicionei **tags** para ajudar na identificação dos recursos.

## Observação
Adicionei comentarios a cada parte do codigo com objetivo de facilitar o entendimento dos recursos, esses comentários explicam cada parte do código, como a criação de recursos e configuração de segurança. Além disso, foi necessário remover as **tags** na seção de **Security Group** do código, pois sua presença estava impactando a execução correta do mesmo.


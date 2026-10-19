# Contexto de implementação: Kubernetes eBPF Security Lab

Implemente um projeto de portfólio chamado **Kubernetes eBPF Security Lab** para demonstrar segurança e observabilidade de rede e runtime em Kubernetes usando Cilium, Hubble e Tetragon.

O projeto deve ser **um único repositório**, com código, aplicação, políticas e cenários compartilhados. Ele terá dois alvos de implantação independentes:

1. **Local com kind** — ambiente rápido para desenvolvimento e demonstrações, iniciado com um único comando.
2. **AWS EKS** — ambiente em nuvem provisionado por IaC, com configuração própria de rede, IAM e custos.

Não duplicar aplicação e políticas entre os ambientes. Manter separados apenas os arquivos e processos específicos de provisionamento e implantação de cada alvo.

## Estrutura desejada

```text
kubernetes-ebpf-security-lab/
├── README.md
├── Makefile
├── app/                         # Frontend, API, PostgreSQL e testes
├── k8s/
│   └── base/                    # Workloads e serviços compartilhados
├── policies/
│   ├── cilium/                  # Políticas de rede
│   └── tetragon/                # Observação e enforcement de runtime
├── demos/                       # Cenários e validações compartilhados
├── deployments/
│   ├── local-kind/
│   │   ├── cluster/             # Configuração kind
│   │   ├── helm/                # Valores locais
│   │   └── overlay/             # Ajustes Kubernetes locais
│   └── aws-eks/
│       ├── tofu/                # Terraform ou OpenTofu
│       ├── helm/                # Valores EKS
│       └── overlay/             # Ajustes Kubernetes para EKS
├── scripts/
└── evidence/                    # Resultados de testes executados
```

## Componentes e demonstrações

- **Cilium:** CNI e políticas de conectividade entre workloads.
- **Hubble:** observação dos fluxos permitidos e bloqueados, com Relay e UI.
- **Tetragon:** eventos de processos e acesso a arquivos; começar em observação e testar enforcement controlado em workload dedicado.
- **Aplicação:** fluxo frontend → API → PostgreSQL.
- **Cenários:** baseline funcional, microsegmentação, análise de fluxos, observação e enforcement em runtime, além de troubleshooting e recuperação.

As políticas de demonstração devem ter escopo explícito e usar dados fictícios. Não apresentar os cenários como configuração de produção nem como proteção genérica contra qualquer acesso.

## Alvo local: `deployments/local-kind`

O comando `make up` deve ser a entrada única para preparar o ambiente local. Com os pré-requisitos instalados, ele deve validar ferramentas e recursos, criar o cluster kind, instalar Cilium, Hubble e Tetragon, construir e carregar as imagens próprias, implantar a aplicação, aguardar a prontidão e executar testes básicos.

Ao terminar, informar os endereços locais da aplicação e do Hubble. Se uma etapa falhar, registrar diagnóstico e indicar onde parou. `make down` deve parar os encaminhamentos locais e remover apenas o cluster desta POC. Cenários de bloqueio e enforcement devem ser executados por comandos separados, para manter o baseline funcional.

## Alvo AWS: `deployments/aws-eks`

Provisionar uma VPC, cluster EKS padrão e nós Linux EC2 usando Terraform ou OpenTofu. Fixar versões e proteger credenciais. Documentar os requisitos de IAM, CIDRs, subnets, rotas, security groups, AMI e kernel.

Usar Cilium como CNI primário com AWS ENI/IPAM, a menos que haja justificativa documentada para outra configuração. Definir explicitamente como o AWS VPC CNI será tratado para evitar conflitos. Não usar EKS Auto Mode ou Fargate para esse alvo com Cilium alternativo. Validar compatibilidade das versões e a sequência de bootstrap antes de instalar workloads.

Oferecer comandos separados, como `make eks-up` e `make eks-down`. Antes de criar ou destruir recursos, conferir conta, região e nome do ambiente; mostrar uma estimativa de custos e o plano de IaC. Não expor a UI do Hubble publicamente; usar acesso local restrito.

## Critérios de aceite

- O README explica a arquitetura geral e as diferenças entre local e EKS.
- `make up` reproduz o laboratório local e valida a aplicação.
- A implantação EKS usa IaC e possui comandos próprios de criação, validação e destruição.
- Os mesmos cenários funcionais são executados nos dois ambientes, com ajustes documentados onde necessário.
- Evidências incluem versões, comandos, resultado esperado e observado.
- Nenhum teste é marcado como aprovado antes de ser executado.
- Cluster Mesh, segundo provedor e produção permanecem como roadmap, fora do escopo inicial.

## Referências oficiais

- https://docs.cilium.io/en/stable/installation/kind/
- https://docs.cilium.io/en/stable/installation/k8s-install-helm/
- https://docs.cilium.io/en/stable/observability/hubble/
- https://tetragon.io/docs/installation/kubernetes/
- https://docs.aws.amazon.com/eks/latest/userguide/alternate-cni-plugins.html
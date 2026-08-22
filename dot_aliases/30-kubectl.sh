# Kubernetes (kubectl)
alias k=kubectl
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kgns='kubectl get ns'
alias kgd='kubectl get deployments'
alias kdesc='kubectl describe'
alias klog='kubectl logs -f'
alias kctx='kubectl config use-context'
alias kctxs='kubectl config get-contexts'
alias kns='kubectl config set-context --current --namespace'

# Lo específico de la empresa (eks-refresh, bk-eks) vive en el
# ~/.zshrc.local de la máquina de trabajo, no aquí.

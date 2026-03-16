<div align="center">

![Banner](https://capsule-render.vercel.app/api?type=waving&color=0:000000,50:0f172a,100:000000&height=180&section=header&text=Agent%20AI%20Ops&fontSize=42&fontColor=2563eb&animation=fadeIn&fontAlignY=38&desc=GPU-Accelerated%20%7C%20Self-Hosted%20%7C%20IaC%20%7C%20DevOps&descAlignY=60&descAlign=50)

[![Docker Compose](https://img.shields.io/badge/Docker_Compose-3.8-2496ED?style=flat-square&logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![NVIDIA CUDA](https://img.shields.io/badge/NVIDIA_CUDA-GPU_Accelerated-76B900?style=flat-square&logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)
[![Ollama](https://img.shields.io/badge/Ollama-LLaMA_3.1-000000?style=flat-square&logo=ollama&logoColor=white)](https://ollama.com/)
[![n8n](https://img.shields.io/badge/n8n-Automation-EA4B71?style=flat-square&logo=n8n&logoColor=white)](https://n8n.io/)
[![Prometheus](https://img.shields.io/badge/Prometheus-v3.5.0-E6522C?style=flat-square&logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?style=flat-square&logo=grafana&logoColor=white)](https://grafana.com/)
[![Bash](https://img.shields.io/badge/IaC-Bash_Script-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License: GPL](https://img.shields.io/badge/License-GNU_GPL-4EAA25?style=flat-square&logo=gnu&logoColor=white)](LICENSE)

*Stack de infraestructura IA completo y listo para producción — sin dependencias en la nube, con soberanía total de datos.*

</div>


---


## Descripción general

**Agent AI Ops** es prototipo de plataforma de IA de nivel de producción y autohospedada, diseñada para ejecutar modelos de lenguaje grande (LLM), búsqueda vectorial y automatización inteligente íntegramente en tu propio hardware: sin dependencias de la nube, sin cuotas de uso y con soberanía total sobre los datos.

Orquestada a través de un único archivo declarativo `docker-compose.yml` y gestionada por una CLI personalizada `agentai-ops.sh`, la pila pone en marcha 15 servicios en contenedores que cubren todo el proceso de IA: desde la inferencia de modelos y el almacenamiento vectorial hasta la automatización de flujos de trabajo y la observabilidad de la GPU en tiempo real.


---
 
## Architecture
 
<p align="center">
  <img src="Architecture.svg"
       alt="Architecture System"
       width="900"
       style="max-width: 100%; height: auto; border-radius: 12px; box-shadow: 0px 8px 24px rgba(37, 99, 235, 0.18);">
</p>
 
---

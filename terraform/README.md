# Azure VNet 피어링 및 VM 배포 테라폼 프로젝트

이 테라폼 프로젝트는 다음과 같은 Azure 리소스를 생성합니다:

- 리소스 그룹: rg-testbed (한국 중부 리전)
- 3개의 VNet (vnet1, vnet2, vnet3)과 각각의 subnet-main
- VNet 간 풀-메시 피어링
- 각 VNet의 subnet-main에 Ubuntu 22.04 LTS VM 배포

## 사전 요구사항

1. Azure CLI 설치
2. 테라폼 설치
3. Azure 구독에 대한 접근 권한
4. SSH 공개키 (~/.ssh/id_rsa.pub)

## 사용 방법

1. Azure CLI로 로그인:
```bash
az login
```

2. 테라폼 초기화:
```bash
terraform init
```

3. 실행 계획 확인:
```bash
terraform plan
```

4. 인프라 배포:
```bash
terraform apply
```

5. 인프라 삭제:
```bash
terraform destroy
```

## 출력값

- resource_group_name: 생성된 리소스 그룹 이름
- vnet_ids: 각 VNet의 ID
- vm_public_ips: 각 VM의 공개 IP 주소
- vm_private_ips: 각 VM의 프라이빗 IP 주소 
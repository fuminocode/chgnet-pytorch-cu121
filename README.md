# chgnet-pytorch-cu121

CHGNet 0.3.8、PyTorch 2.5.1（CUDA 12.1）、pymatgen 2023.11.12 与
Python 3.11 运行环境；支持 GitHub Actions 构建和 Apptainer / Slurm 集群运行。

2026-10-20。本仓库只保存运行环境配方和集群启动脚本。
本地无需安装Docker；镜像由GitHub Actions手动构建。上传文件不会触发构建或发布。
SOURCE_MANIFEST.json和TEMPLATE_CHECKS.json记录模板准备时的状态；
镜像是否构建或发布，以对应Actions运行记录为准。

## 镜像包含什么

- 固定摘要的官方Python3.11.16 Bookworm基础镜像。
- uv0.12.16，以及原运行包的pyproject.toml/uv.lock所锁定的依赖。
- PyTorch2.5.1+cu121、CHGNet0.3.8、pymatgen2023.11.12等完整运行依赖。
- 第三方CHGNet发行包自带的官方预训练文件；没有本项目训练权重。
- 少量版本/导入检查脚本和依赖来源信息；没有科研模型实现、CIF、标签或凭据。

Dockerfile使用逐项COPY和.dockerignore白名单。科研代码和数据仍使用服务器
已有项目目录，运行时绑定；镜像内Python固定为/opt/lisuperionic/venv/bin/python。
仅环境镜像也包含第三方库代码与其许可证，公开发布时应遵守相关再分发条款。

## 1. 准备Docker Hub镜像仓库

本仓库根目录包含Dockerfile和.github/workflows/build-runtime.yml，
可直接用于Actions。GitHub仓库与Docker Hub镜像仓库的公开/私有设置彼此独立。
另行建立Docker Hub镜像仓库，建议同样命名为chgnet-pytorch-cu121，
完整镜像名为你的Docker Hub命名空间/chgnet-pytorch-cu121。

不要上传本机虚拟环境、科研数据或token；令牌通过GitHub的Secrets界面配置。

## 2. 配置Actions

在GitHub仓库Settings → Secrets and variables → Actions中设置：

| 类型 | 名称 | 内容 |
|---|---|---|
| Variable | DOCKERHUB_IMAGE | 小写的命名空间/镜像仓库，例如你的Docker Hub用户名/chgnet-pytorch-cu121 |
| Secret | DOCKERHUB_USERNAME | Docker Hub登录用户名 |
| Secret | DOCKERHUB_TOKEN | 对目标镜像仓库有推送权限的访问令牌 |

token只填在GitHub Secrets，不写进Dockerfile、workflow或聊天。
Actions使用官方checkout/buildx/login/build-push组件，已固定到读取时的提交；
来源与版本记录在ACTION_PINS.json。默认只允许手动workflow_dispatch，
没有push或pull_request自动发布触发器。

## 3. 运行构建并发布

进入Actions → Build CHGNet runtime image → Run workflow。
第一次publish=false可以只构建检查；成功后再手动运行publish=true发布。
也可第一次直接选择publish=true；Dockerfile中的版本/CPU导入检查失败
会使构建失败，不会推送一个通过不了这些检查的最终镜像。

构建固定为linux/amd64。GitHub机器只做依赖安装、打包和CPU导入检查，
不加载本项目模型，不训练，不访问CIF，不执行GPU检查。
每次运行记录磁盘余量；CUDA镜像较大，普通runner是否够用以实际首跑为准。
没有自动切换付费runner或清理非本工作流文件。使用完成镜像层的GHA缓存，
没有把依赖下载缓存留进最终镜像，减少占用。

成功发布后，任务Summary给出固定摘要地址：

```text
docker.io/你的命名空间/你的镜像仓库@sha256:实际摘要
```

使用这个摘要固定镜像；cu121-py311-v1是便于识别的可更新标签，不能代替
研究运行中的固定摘要。日志与源码提交也应保存。

## 4. 集群安装完整镜像

此处仍不连接服务器。以下示例面向公有镜像。私有镜像需要另外配置可信
registry认证，第三方加速服务是否支持私有镜像尚未核实。

在服务器创建目录，将本模板cluster/里的六个脚本上传进去：

```bash
mkdir -p /public/home/xiaohe2/zizhangw/chgnet-runtime-ci-20261020/logs
cd /public/home/xiaohe2/zizhangw/chgnet-runtime-ci-20261020
bash setup-runtime.sh --check-paths
```

把下一条命令中的地址换成Actions Summary里的真实地址。根据用户此前
成功拉取基础镜像的记录，可以尝试将docker.io改为docker.rimuru.cc，
保留完整仓库路径和sha256摘要；新命名空间的加速可用性尚未实测。

```bash
bash setup-runtime.sh 'docker://docker.rimuru.cc/你的命名空间/你的镜像仓库@sha256:实际摘要'
```

服务器会下载完整镜像并转换为SIF，检查依赖版本/CPU导入与原1009文件
指纹。首次仍需下载完整运行环境，后续运行复用已有SIF；镜像分层不会
让首次下载消失。集群端没有pip install或uv sync，不再逐个下载CUDA包。
服务器原包、旧环境、旧SIF、历史运行不改；新镜像使用新的个人文件名。

安装成功后：

```bash
source /public/home/xiaohe2/zizhangw/wzz_bashrc
wzzpython --version
wzzscripts
```

个人wzz_bashrc按既有授权维护：保留原内容，修改前备份，重复不追加。
公共账号.bashrc不修改。新快捷入口末尾覆盖旧同名函数。

## 5. 小检查和正式计算

若有tzhu_g权限且当前gpu12可用，先验证两个请求，再提交小检查：

```bash
sbatch --test-only --partition=tzhu_g --nodelist=gpu12 smoke.slurm
sbatch --test-only --partition=tzhu_g --nodelist=gpu12 train.slurm
sbatch --partition=tzhu_g --nodelist=gpu12 smoke.slurm
```

不能使用tzhu_g时，去掉上述分区和节点参数，使用默认gpu分区排队。
小检查1GPU/4CPU/32G主机RAM/30分钟；正式1GPU/4CPU/64G主机RAM/12小时。
任务名以wzz-开头，使用apptainer --nv及Slurm原始GPU可见性，不指定物理卡。

小检查成功需退出0、SMOKE PASSED、preflight和adapter-check的status=passed。
原22GiB空闲显存/24GiB有效RAM是准入检查，不是592位点最大结构的实测峰值。
小检查通过后才提交train.slurm。仍使用原482开发结构、原标签与划分，
不分块、不删大结构、不使用原67最终评价材料。

结果目录：

```text
/public/home/xiaohe2/zizhangw/projects/chgnet-server-20261013-002/
  experiments/runs/chgnet-runtime-ci-20261020-JOBID/
```

status.json须为completed、482特征核验passed、两组LR独立核验passed，
并核对logs/launch-运行ID/exit_code.txt为0。下载完整run、launch和调度日志。
任务号或队列消失不等于科学计算成功；失败日志也保留。

## 镜像分层的边界

Docker/OCI按文件系统层组织镜像，相同层可被继承和缓存复用。
FROM可以选择NVIDIA/CUDA或PyTorch基础镜像，但它不是运行时module load。
本模板先保留Python基础镜像和原uv锁，避免与额外CUDA基础镜像重复安装
或隐式更换Python/PyTorch版本。科研代码通过绑定更新，无需因此重建环境。
Apptainer会把所选OCI层转换为单个SIF，实际运行复用SIF；后续新镜像
可能复用OCI缓存，但转换过程不能等同于Docker原生增量启动。

官方依据：

```text
https://docs.docker.com/build/ci/github-actions/
https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/
https://docs.github.com/en/actions/reference/runners/github-hosted-runners
https://apptainer.org/docs/user/main/docker_and_oci.html
```

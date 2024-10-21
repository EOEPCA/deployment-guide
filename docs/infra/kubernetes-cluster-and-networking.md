> This is just one example of how to setup a Kubernetes cluster and networking that is required for deploying EOEPCA+ building blocks. This guide is intended to be a starting point and may need to be adapted based on your specific requirements.

### 1. Generate SSH Key Pair

Generate an SSH key pair for accessing your virtual machines.

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/eoepca_key
```

- **Public Key**: `~/.ssh/eoepca_key.pub`
- **Private Key**: `~/.ssh/eoepca_key`

Upload the public key (`eoepca_key.pub`) to your cloud provider's SSH key management section or use it during instance creation.

### 2. Set Up the Network

Configure the network to allow your instances to communicate and access the internet.

1. **Create a Virtual Network**:

   - Use your cloud provider's interface to create a new virtual network (VPC/VNet) with an appropriate CIDR block (e.g., `192.168.0.0/16`).

2. **Create Subnets**:

   - Within the virtual network, create subnets for your instances (e.g., `192.168.1.0/24` for Kubernetes nodes).

3. **Set Up Internet Access**:

   - Attach an internet gateway to your virtual network.
   - If using private subnets, set up a NAT gateway for instances that need internet access.

4. **Configure Routing**:

   - Ensure your routing tables direct traffic appropriately between subnets and to the internet gateway or NAT gateway.

5. **Configure Security Groups/Firewall Rules**:

   - Define inbound and outbound rules to allow necessary traffic.
   - **Allow Inbound Traffic On**:
     - **SSH (22)**: For SSH access to instances.
     - **HTTP (80) and HTTPS (443)**: For web traffic to applications.
     - **Kubernetes API (6443)**: For cluster management via the API server.

### 3. Deploy the Load Balancer

Set up a load balancer to distribute traffic to your Kubernetes cluster.

1. **Create the Load Balancer**:

   - Use your cloud provider's load balancer service (e.g., AWS ELB, Azure Load Balancer).
   - Configure listeners for the following ports:
     - **TCP 6443**: Forwarded to the Kubernetes API server on control plane nodes.
     - **TCP 80 and 443**: Forwarded to the ingress controllers on worker nodes.

2. **Assign a Public IP**:

   - Allocate and associate a public IP address with the load balancer.
   - Update your DNS records to point to this IP if using a custom domain.

3. **Configure Backend Pools**:

   - **For Port 6443**:
     - Add the private IP addresses of your control plane node(s).
   - **For Ports 80 and 443**:
     - Add the private IP addresses of your worker nodes (where the ingress controller will run).

### 4. Create the Bastion Host

A bastion host provides secure access to instances within private networks.

1. **Create the Bastion VM**:

   - Launch a Linux VM (e.g., Ubuntu Server).
   - Assign a public IP address for SSH access.
   - Place it in a subnet with access to your other instances.

2. **Configure Security Rules**:

   - Allow inbound SSH (port 22) from your trusted IP addresses.
   - Use the SSH key pair you generated earlier for authentication.

3. **Test SSH Connection**:

   ```bash
   ssh -i ~/.ssh/eoepca_key username@bastion_public_ip
   ```

   Replace `username` and `bastion_public_ip` with your actual details.

### 5. Deploy the Kubernetes Cluster with RKE

Set up a Kubernetes cluster using Rancher Kubernetes Engine (RKE).

1. **Prepare the Kubernetes Nodes**:

   - **Launch Virtual Machines**:
     - **Control Plane Node(s)**: Create one or more VMs to serve as control plane nodes.
     - **Worker Nodes**: Create one or more VMs to serve as worker nodes.
   - **Install Docker on All Nodes**:
     - SSH into each node and install Docker:
       ```bash
       curl https://releases.rancher.com/install-docker/24.0.sh | sh
       sudo usermod -aG docker $USER
       ```
     - Log out and back in for group changes to take effect.

2. **Configure Security Groups/Firewall Rules**:

   - Ensure that all required ports are open between the nodes:
     - **Internal Communication**: Allow all traffic between cluster nodes (TCP and UDP ports 0-65535).
     - **SSH (22)**: Allow SSH access from the bastion host.
     - **Kubernetes API (6443)**: Allow access from the bastion host or trusted networks.

3. **Create the RKE Cluster Configuration File (`cluster.yml`)**:

   - Create a `cluster.yml` file defining your cluster configuration.
     ```yaml
     nodes:
       - address: control_plane_node_ip
         user: your_username
         role:
           - controlplane
           - etcd
       - address: worker_node_ip
         user: your_username
         role:
           - worker
     bastion_host:
       address: bastion_host_ip
       user: your_username
     ```
     Replace placeholders with actual IP addresses and usernames.

4. **Deploy the Kubernetes Cluster**:

   - Run RKE from your local machine:
```bash
rke up
```
     This will deploy the Kubernetes cluster using the configuration in `cluster.yml`.

5. **Configure `kubectl` to Access the Cluster**:

   - Copy the generated kubeconfig file:
     ```bash
     mkdir -p ~/.kube
     cp kube_config_cluster.yml ~/.kube/config
     export KUBECONFIG=~/.kube/config
     ```
   - Verify access to the cluster:
     ```bash
     kubectl get nodes
     ```

---

## Next Steps

Now that your Kubernetes cluster is up and running, you need to set up additional components that are essential for deploying EOEPCA+ building blocks. These components often vary between deployments, so we've provided separate guides for each:

1. **Ingress Controller**:

   - Install an ingress controller to manage external access to services within your cluster.
   - See the [Ingress Controller Setup Guide](ingress-controller.md) for detailed instructions.

2. **TLS Certificate Management**:

   - Configure TLS certificates for secure communication.
   - Options include using `cert-manager` with Let's Encrypt, self-signed certificates, or manual certificate management.
   - See the [TLS Certificate Management Guide](tls/overview.md) for detailed instructions.

3. **Storage Provisioning**:

   - Set up a storage provisioner, such as NFS, for dynamic volume provisioning.
   - See the [Storage Classes Setup Guide](storage/storage-classes.md) for detailed instructions.

Once these components are in place, you'll be ready to deploy the EOEPCA+ building blocks.

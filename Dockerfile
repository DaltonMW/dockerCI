# Copyright 2019 - 2025 The MathWorks, Inc. 
# docker build --build-arg MATLAB_DOCKER_RELEASE=<matlab-docker-release> 
#              --build-arg MATLAB_VERSION=<matlab-release> 
# 		         --build-arg GITLAB_TOKEN=<gitlab-token> 
#		           --build-arg MATLAB_BATCH_TOKEN=<matlab-token> 
#		           --build-arg IMAGE_NAME=<image-image> 
#              -t <image-image> 
#		           -f <dockerfile-name> . 
# 
# Example: $ docker build --build-arg PATH_TO_LICENSE=<path-to-license> --build-arg GITLAB_TOKEN=<gitlab-token> --build-arg MATLAB_BATCH_TOKEN="<USER>|TOKEN_ML|<TOKEN>" -t matlab_image -f matlab.Dockerfile . 

# To specify which MATLAB release to install in the container, edit the value of the MATLAB_RELEASE argument. 
# Use lower case to specify the release, for example: ARG MATLAB_RELEASE=r2023b 
ARG MATLAB_DOCKER_RELEASE=r2023b-ubuntu22.04 
ARG MATLAB_VERSION=r2023b 
ARG MATLAB_BATCH_TOKEN="<USER>|TOKEN_ML|<TOKEN>" 
ARG GITLAB_TOKEN=<TOKEN> 
ARG IMAGE_NAME=matlab_image 
ARG PATH_TO_LICENSE=<PATH_TO_LICENSE> 

# When you start the build stage, this Dockerfile by default uses the Ubuntu-based matlab-deps image. 
# To check the available matlab-deps images, see: https://hub.docker.com/r/mathworks/matlab-deps 
FROM mathworks/matlab-deps:${MATLAB_DOCKER_RELEASE} 

# Declare the global argument to use at the current build stage 
ARG MATLAB_VERSION 
ARG MATLAB_BATCH_TOKEN 
ARG GITLAB_TOKEN 
ARG IMAGE_NAME 
ARG PATH_TO_LICENSE 

RUN sudo apt-get update && \ 
    sudo apt-get install --no-install-recommends --yes \ 
    curl && \  
    sudo apt-get clean && sudo apt-get autoremove 

RUN curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash && \ 
    sudo apt-get install --no-install-recommends --yes \ 
    gitlab-runner && \  
    sudo apt-get clean && sudo apt-get autoremove && \  
    gitlab-runner start && \  
    sudo gitlab-runner register --non-interactive \ 
    	--url "https://external-git.mathworks.com/" \ 
   	  --token "${GITLAB_TOKEN}" \ 
      --docker-image ${IMAGE_NAME} \ 
   	  --executor "shell" 

# Install mpm dependencies 
RUN export DEBIAN_FRONTEND=noninteractive && \ 
    sudo apt-get update && \ 
    sudo apt-get install --no-install-recommends --yes \ 
        wget \ 
        ca-certificates \ 
        xvfb \ 
        build-essential \ 
        clang \ 
        libopenblas-dev \ 
        liblapacke-dev \ 
        liblapack-dev \ 
        libomp-dev \ 
        unzip \ 
        iproute2 \ 
        git \ 
        libeigen3-dev \ 
        cmake \ 
        psmisc && \ 
    sudo apt-get clean && sudo apt-get autoremove 

RUN sudo apt-get update && sudo apt-get install libunwind-dev -y && \ 
    sudo apt-get clean && sudo apt-get autoremove 

# Install dependencies for matlab-proxy 
RUN DEBIAN_FRONTEND=noninteractive && \ 
    sudo apt-get update && sudo apt-get install --no-install-recommends -y \ 
    python3 \ 
    python3-pip \ 
    && sudo apt-get clean \ 
    && sudo rm -rf /var/lib/apt/lists/* 
RUN python3 -m pip install matlab-proxy 

# Add "matlab_user" user and grant sudo permission. 
RUN adduser --shell /bin/bash --disabled-password --gecos "" matlab_user && \ 
    echo "matlab_user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/matlab_user && \ 
    chmod 0440 /etc/sudoers.d/matlab_user 

# Set user and work directory 
USER matlab_user 
WORKDIR /home/matlab_user 

# Run mpm to install MATLAB in the target location and delete the mpm installation afterwards 
# Add toolboxes on --products line replacing spaces with _ aka Simulink_Test 
# Note: Simulink_Code_Inspector is only supported by mpm when installing from an iso file:  
RUN wget -q https://www.mathworks.com/mpm/glnxa64/mpm && \ 
    chmod +x mpm && \ 
    sudo ./mpm install \ 
        --release=${MATLAB_VERSION} \ 
        --destination=/opt/matlab \ 
        --products MATLAB Simulink Stateflow \ 
        Requirements_Toolbox \ 
        Simulink_Check CI/CD_Automation_for_Simulink_Check Simulink_Design_Verifier \ 
        Simulink_Test Simulink_Coverage \ 
        MATLAB_Coder MATLAB_Compiler Simulink_Coder Simulink_Compiler Embedded_Coder \ 
        Polyspace_Bug_Finder_Server Polyspace_Code_Prover_Server \ 
        MATLAB_Report_Generator Simulink_Report_Generator \ 
        DSP_System_Toolbox Simulink_3D_Animation Phased_Array_System_Toolbox \  
        Computer_Vision_Toolbox Image_Processing_Toolbox \ 
        System_Identification_Toolbox Instrument_Control_Toolbox Aerospace_Toolbox \ 
        Aerospace_Blockset Signal_Processing_Toolbox Symbolic_Math_Toolbox \ 
        Automated_Driving_Toolbox DDS_Blockset Geoid_Data_for_Aerospace_Toolbox \ 
        || (echo "MPM Installation Failure. See below for more information:" && cat /tmp/mathworks_root.log && false) && \ 
    sudo rm -rf mpm /tmp/mathworks_root.log && \ 
    sudo ln -s /opt/matlab/bin/matlab /usr/local/bin/matlab 

# One of the following 3 ways of configuring the license server to use must be 
# uncommented. 

# 1) BATCH TOKEN 
# Install matlab-batch to enable the use of MATLAB batch licensing tokens. 
RUN wget -q https://ssd.mathworks.com/supportfiles/ci/matlab-batch/v1/glnxa64/matlab-batch \ 
    && sudo mv matlab-batch /usr/local/bin \ 
    && sudo chmod +x /usr/local/bin/matlab-batch 

# 2) LICENSE SERVER 
#ARG LICENSE_SERVER 
# Specify the host and port of the machine that serves the network licenses 
# if you want to bind in the license info as an environment variable. This 
# is the preferred option for licensing. It is either possible to build with 
# Something like --build-arg LICENSE_SERVER=27000@MyServerName, alternatively 
# you could specify the license server directly using 
# ENV MLM_LICENSE_FILE=27000@flexlm-server-name 
#ENV MLM_LICENSE_FILE=$LICENSE_SERVER 

# 3) LICENSE FILE 
# Alternatively, you can put a license file into the container. 
# You should fill this file out with the details of the license 
# server you want to use and uncomment the following line: 
#COPY ${PATH_TO_LICENSE} /opt/matlab/licenses/ 
# -OR-
#ADD ${PATH_TO_LICENSE} /opt/matlab/licenses/ 

ENV ENV="/home/matlab_user/.profile" 
ENV BASH_ENV="/home/matlab_user/.profile" 
ENV MLM_LICENSE_TOKEN=${MATLAB_BATCH_TOKEN} 

ENTRYPOINT ["xvfb-run"] 
CMD ["/bin/bash"] 

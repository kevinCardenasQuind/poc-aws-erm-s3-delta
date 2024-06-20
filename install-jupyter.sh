#!/bin/bash
sudo python3 -m pip install --upgrade pip
sudo python3 -m pip install jupyter
sudo mkdir -p /home/hadoop/.jupyter
sudo chown -R hadoop:hadoop /home/hadoop/.jupyter
sudo -u hadoop jupyter notebook --generate-config
sudo bash -c 'echo "c.NotebookApp.ip = '\''*'\''" >> /home/hadoop/.jupyter/jupyter_notebook_config.py'
sudo bash -c 'echo "c.NotebookApp.open_browser = False" >> /home/hadoop/.jupyter/jupyter_notebook_config.py'
sudo bash -c 'echo "c.NotebookApp.port = 8888" >> /home/hadoop/.jupyter/jupyter_notebook_config.py'
sudo -u hadoop jupyter notebook --notebook-dir=/mnt/jupyter &

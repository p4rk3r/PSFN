# PSFN

Lin, L., Li, J., Shen, H., Zhao, L., Yuan, Q., & Li, X. (2021). Low-Resolution Fully Polarimetric SAR and High-Resolution Single-Polarization SAR Image Fusion Network. IEEE Transactions on Geoscience and Remote Sensing.

paper link:https://ieeexplore.ieee.org/abstract/document/9583928/

# Steps to Run in Docker
* `pip install pipreqs`
* `pipreqs $PWD`
* `docker run -it -v $PWD:/project -w /project --entrypoint /bin/bash python:python3-bookworm`
* `pip install pipenv`
* `pipenv lock`
* `exit`
* `docker run -it -v $PWD:/project -w /project --entrypoint /bin/bash python:python3-bookworm`
* `pip install pipenv`
* `PIPENV_VENV_IN_PROJECT=1 pipenv install --deploy`
* `python3 ./train.py`
* etc

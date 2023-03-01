from brownie import *


def main():
    deploy_account = accounts[0]
    level_one_account = accounts[1]
    level_two_account = accounts[2]
    token_contract = accounts[0].deploy(Genealogy,{"from":deploy_account})
    stake_contract = accounts[0].deploy({"from":deploy_account})
    Genealogy.deploy({"from":deploy_account})
    print("successfully deployed")


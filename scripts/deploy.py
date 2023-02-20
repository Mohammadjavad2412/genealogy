from brownie import Genealogy,accounts,config


def main():
    account = accounts.load('development_account')
    Genealogy.deploy({"from":account})
    print("successfully deployed")


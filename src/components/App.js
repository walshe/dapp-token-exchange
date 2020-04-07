import React, { Component } from 'react'
import './App.css'
import Navbar from './Navbar'
import Content from './Content'
import { connect } from 'react-redux'
import {
  loadWeb3,
  loadAccount,
  loadToken,
  loadExchange
} from '../store/interactions'
import { contractsLoadedSelector } from '../store/selectors'

class App extends Component {
  componentWillMount() {
    //called before ui is rendered
    this.loadBlockchainData(this.props.dispatch)
  }

  async loadBlockchainData(dispatch) {
    //load web3 lib whih interacts with the blockchain
    const web3 = loadWeb3(dispatch)
    //Guesses the chain the node is connected by comparing the genesis hashes.
    await web3.eth.net.getNetworkType()

    //each network e.g. main, kovan
    const networkId = await web3.eth.net.getId()
    //load users account into web3
    await loadAccount(web3, dispatch)
    //load out Token erc20 smart contract crypto currency
    const token = await loadToken(web3, networkId, dispatch)
    if(!token) {
      window.alert('Token smart contract not detected on the current network. Please select another network with Metamask.')
      return
    }
    //lpoad our exchange smart contract
    const exchange = await loadExchange(web3, networkId, dispatch)
    if(!exchange) {
      window.alert('Exchange smart contract not detected on the current network. Please select another network with Metamask.')
      return
    }
  }

  render() {
    return (
      <div>
        <Navbar />
        { this.props.contractsLoaded ? <Content /> : <div className="content"></div> }
      </div>
    );
  }
}

function mapStateToProps(state) {
  return {
    contractsLoaded: contractsLoadedSelector(state)
  }
}

export default connect(mapStateToProps)(App)

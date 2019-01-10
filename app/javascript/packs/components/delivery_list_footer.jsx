import React, { Component } from 'react';

class DeliveryListFooter extends Component {
  constructor(props) {
    super(props);
    this.state = { filter: null };
  }

  handleClick = (e) => {
    e.preventDefault();
    const { filter } = this.state;
    const newFilter = (filter === null) ? 'frozen' : null;
    this.setState({ filter: newFilter })
    this.props.onFilterChanged(newFilter);
  }

  render(){
    const { filter } = this.state;
    const { onFilterChanged } = this.props;
    let className = filter ? 'is-active' : ''
    return (
      <div className="delivery-list-footer">
        <a className={"delivery-list-footer__button " + className} href="#" onClick={this.handleClick}>冷凍のみ</a>
      </div>
    );
  }
}

export default DeliveryListFooter;

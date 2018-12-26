import React from 'react';
import PropTypes from 'prop-types';

const itemCategory = (category) => {
  if (category === 'cold') {
    return <span className='badge badge-info'>冷</span>;
  }
  else if (category === 'frozen') {
    return <span className='badge badge-primary'>凍</span>
  }
  else {
    return '';
  }
}
const Item = (props) => {
  const { data, shopName } = props;
  const classes = ['delivery-item'];
  if (data.quantity == 0)
    classes.push('is-zero');
  if (data.isChild)
    classes.push('is-child');
  return (
    <li className={classes.join(' ')}>
      <div className={'delivery-item__mark ' + shopName}></div>
      {data.image_url ? <div className='delivery-item__image'><img src={data.image_url} /></div> : ''}
      <div className='delivery-item__name'>{itemCategory(data.category)} {data.name}</div>
      <div className='delivery-item__quantity'>{data.quantity}</div>
    </li>
  );
};

Item.propTypes = {
  data: PropTypes.object,
  shopName: PropTypes.string,
};

export default Item;

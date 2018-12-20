import React from 'react';
import PropTypes from 'prop-types';

const Delivery = (props) => {
  const { delivery } = props;
  return (
    <li className={'delivery-header ' + delivery.shop}>
      <div className='delivery-header__content'>
        {delivery.delivery_date}：{delivery.shop_display_name} {delivery.name}
      </div>
    </li>
  );
};

Delivery.propTypes = {
  delivery: PropTypes.object,
};

export default Delivery;

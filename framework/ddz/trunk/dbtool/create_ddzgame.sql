create database if not exists #DB#;
use #DB#;
set names utf8;
#创建角色账号表  insert  
create table if not exists role_auth(
                                        uid int(11) NOT NULL DEFAULT '0' comment '账号id',
                                        rid int(11) NOT NULL DEFAULT '0' comment '角色id',
                                        create_time int(11) NOT NULL DEFAULT '0' comment '创建时间',
                                        update_time timestamp on update current_timestamp default current_timestamp comment '创建时间',
                                        primary key(uid)
                                    )engine = InnoDB, charset = utf8;
#创建玩家基本信息表 insert update
create table if not exists role_info(
                                          rid int(11) NOT NULL DEFAULT '0' comment '角色id',
                                          username varchar(128) not null DEFAULT '' comment '用户名',
                                          rolename varchar(128) not null DEFAULT '' comment '用户昵称',
                                          logo varchar(512) not null DEFAULT '' comment 'logo url 头像',
                                          phone varchar(24) not null DEFAULT '' comment '手机号',
                                          sex int(11) NOT NULL DEFAULT '0' comment '性别',
                                          update_time timestamp on update current_timestamp default current_timestamp,
                                          primary key(rid) 
                                    )engine = InnoDB, charset = utf8;
#创建玩家玩斗地主数据表    insert update
create table if not exists role_playgame(
                                            rid int(11) NOT NULL DEFAULT '0' comment '角色id',
                                            totalgamenum int(11) NOT NULL DEFAULT '0' comment '总局数',
                                            winnum int(11) NOT NULL DEFAULT '0' comment '胜局', 
                                            wininseriesnum int(11) NOT NULL DEFAULT '0' comment '当前连胜局数',
                                            highwininseries int(11) NOT NULL DEFAULT '0' comment '最大连胜局数',
                                            update_time timestamp on update current_timestamp default current_timestamp,
                                            primary key(rid) 
                                        )engine = InnoDB, charset = utf8;
#创建玩家货币数据表 insert update
create table if not exists role_money(
                                        rid int(11) NOT NULL DEFAULT '0' comment '角色id',
                                        coin bigint unsigned not null DEFAULT '0' comment '金币',
                                        diamond bigint unsigned not null DEFAULT '0' comment '钻石',
                                        maxcoinnum bigint unsigned not null DEFAULT '0' comment '最大金币数',
                                        update_time timestamp on update current_timestamp default current_timestamp,
                                        primary key(rid) 
                                    )engine = InnoDB, charset = utf8;

#创建玩家在线数据表    insert update                                                                                       
create table if not exists role_online(
                                            rid int(11) NOT NULL DEFAULT '0' comment '角色id',
                                            activetime int(11) NOT NULL DEFAULT '0', 
                                            onlinetime int(11) NOT NULL DEFAULT '0' comment '上线时间',
                                            roomsvr_id varchar(126) NOT NULL DEFAULT '',
                                            roomsvr_table_id int(11) NOT NULL DEFAULT '0',
                                            roomsvr_table_address int(11) NOT NULL DEFAULT '0',
                                            gatesvr_ip varchar(64) NOT NULL DEFAULT '',
                                            gatesvr_port int(11) NOT NULL DEFAULT '0',
                                            gatesvr_id varchar(126) NOT NULL DEFAULT '',
                                            gatesvr_service_address int(11) NOT NULL DEFAULT '0',
                                            update_time timestamp on update current_timestamp default current_timestamp,
                                            primary key(rid) 
                                        )engine = InnoDB, charset = utf8;

#创建玩家战绩数据表   insert update                                                                                      
create table if not exists role_tablerecords(
                                            id bigint NOT NULL AUTO_INCREMENT,
                                            index_id varchar(126) NOT NULL DEFAULT '' comment '索引ID',
                                            table_id int(11) NOT NULL DEFAULT '0' comment '桌子ID',
                                            table_create_time int(11) NOT NULL DEFAULT '0' comment '桌子创建时间',
                                            table_create_rid int(11) NOT NULL DEFAULT '0' comment '桌子创建者的ID',
                                            table_base_coin int(11) NOT NULL DEFAULT '0' comment '自建桌基础分',
                                            rid int(11) NOT NULL DEFAULT '0' comment '玩家id',
                                            record TEXT, 
                                            update_time timestamp on update current_timestamp default current_timestamp,
                                            primary key(id)
                                        )engine = InnoDB, charset = utf8;


#创建玩家邮件表 insert delete
create table if not exists role_mailinfos(
                                            mail_key varchar(30) not null default "" comment '邮件key',
                                            rid int(11) not null comment '角色id',
                                            create_time int(11) not null DEFAULT '0' comment '创建时间',
                                            isattach int(11) not NULL DEFAULT '0' comment '是否有附件',
                                            content varchar(1024) not null DEFAULT '' comment '邮件内容json格式',
                                            reason int(11) not null DEFAULT '0' comment '发放邮件的原因',
                                            update_time timestamp on update current_timestamp default current_timestamp,
                                            primary key(mail_key)
                                        ) engine = InnoDB, charset = utf8;
#玩家ios充值的订单补单记录 insert delete
create table if not exists role_iosbatchs(
                                        rid int(11) not null comment '角色名',
                                        pay_type int(11) not null comment '支付类型',
                                        ios_pay_order varchar(64) not null comment '交易号',
                                        option_data text not null comment '苹果验单支付',
                                        update_time timestamp on update current_timestamp default current_timestamp,
                                        primary key(rid, ios_pay_order)                                          
                                    ) engine = InnoDB, charset = utf8;
#玩家订单表 insert update
create table if not exists role_orders(
                                            rid int(11) NOT NULL DEFAULT '0' comment '角色id',
                                            order_id varchar(32) not null DEFAULT '' comment '订单号',
                                            pid varchar(128) not null DEFAULT '' comment 'ios产品id',
                                            pay_type int(11) NOT NULL DEFAULT '0' comment '支付类型',
                                            price int(11) NOT NULL DEFAULT '0' comment '价格单位分',
                                            good_id int(11) NOT NULL DEFAULT '0' comment '充值商品id',
                                            good_awards varchar(256) not null DEFAULT '' comment '充值商品奖励',
                                            create_time int(11) NOT NULL DEFAULT '0' comment '创建时间',
                                            state int(11) NOT NULL DEFAULT '0' comment '1生成订单，2支付成功，3发货成功',
                                            update_time timestamp on update current_timestamp default current_timestamp,
                                            primary key(rid, order_id)                                            
                                        ) engine = InnoDB, charset = utf8;
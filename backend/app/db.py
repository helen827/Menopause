import aiomysql


async def create_mysql_pool(settings):
    return await aiomysql.create_pool(
        host=settings.mysql_host,
        port=settings.mysql_port,
        user=settings.mysql_user,
        password=settings.mysql_password,
        db=settings.mysql_database,
        minsize=settings.mysql_pool_min_size,
        maxsize=settings.mysql_pool_max_size,
        autocommit=True,
        charset="utf8mb4",
    )


async def close_mysql_pool(pool):
    pool.close()
    await pool.wait_closed()

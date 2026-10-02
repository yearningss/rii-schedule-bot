import asyncio


class SingleFlight:
    """Объединяет одновременные загрузки одного ресурса без хранения результата."""

    def __init__(self):
        self._tasks = {}

    async def run(self, key, loader):
        task = self._tasks.get(key)
        if task is None:
            task = asyncio.create_task(loader())
            self._tasks[key] = task

            def finished(completed):
                if self._tasks.get(key) is completed:
                    self._tasks.pop(key, None)
                # Ошибка извлекается и при отмене всех ожидающих клиентов.
                if not completed.cancelled():
                    completed.exception()

            task.add_done_callback(finished)
        # Закрытие одного HTTP-запроса не отменяет загрузку для остальных.
        return await asyncio.shield(task)

    async def close(self):
        tasks = list(self._tasks.values())
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        self._tasks.clear()

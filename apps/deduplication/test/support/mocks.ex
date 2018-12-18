Mox.defmock(DeduplicationWorkerMock, for: Deduplication.Behaviours.WorkerBehaviour)
Mox.defmock(DeduplicationKafkaMock, for: DeduplicationProducer.Behaviours.KafkaProducerBehaviour)
Mox.defmock(ClientMock, for: Deduplication.Behaviours.ClientBehaviour)
Mox.defmock(PyWeightMock, for: Deduplication.Behaviours.PyWeightBehaviour)

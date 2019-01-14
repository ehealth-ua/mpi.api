Mox.defmock(PersonDeactivatorWorkerMock, for: PersonDeactivator.Behaviours.WorkerBehaviour)

Mox.defmock(PersonDeactivatorKafkaMock,
  for: PersonDeactivatorProducer.Behaviours.KafkaProducerBehaviour
)

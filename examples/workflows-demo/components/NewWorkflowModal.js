/**
 * Index is the "Workflows page"
 */

import { Menu, Button, Input, Modal, Typography } from '@supabase/ui'
import { useState, useEffect } from 'react'


export default function NewWorkflowModal({ visible, onCancel, onConfirm }) {
  const [name, setName] = useState('')
  const [trigger, setDefaultTrigger] = useState('public:users')
  const [default_execution_type, setDefaultExecutionType] = useState('transient')
  const [definition, setDefinition] = useState({
    StartAt: 'Hello World',
    States: {
      'Hello World': {
        Type: 'Task',
        Resource: 'arn:aws:lambda:us-east-1:123456789012:function:HelloWorld',
        End: true,
      },
    },
  })


  return (
    <Modal
      visible={visible}
      onCancel={onCancel}
      onConfirm={() => {
        const payload = { name, default_execution_type, trigger, definition }
        setName('')
        return onConfirm(payload)
      }}
    >
      <Input label="Name" value={name} onChange={(e) => setName(e.target.value)} />
      <Input label="Name" value={trigger} onChange={(e) => setDefaultTrigger(e.target.value)} />
    </Modal>
  )
}